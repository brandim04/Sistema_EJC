const PIX_GUI = 'br.gov.bcb.pix'

function campoEmv(id, valor) {
  const conteudo = String(valor)
  if (conteudo.length > 99) {
    throw new Error(`Campo BR Code ${id} ultrapassa 99 caracteres.`)
  }
  return `${id}${String(conteudo.length).padStart(2, '0')}${conteudo}`
}

function normalizarTextoEmv(valor) {
  return String(valor)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toUpperCase()
    .replace(/[^A-Z0-9 ]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
}

export function calcularCrc16Pix(texto) {
  let crc = 0xffff

  for (const caractere of texto) {
    crc ^= caractere.charCodeAt(0) << 8
    for (let bit = 0; bit < 8; bit++) {
      crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff
    }
  }

  return crc.toString(16).toUpperCase().padStart(4, '0')
}

export function gerarPayloadPix({ chave, recebedor, cidade, valor }) {
  const valorNumerico = Number(valor)
  if (!Number.isFinite(valorNumerico) || valorNumerico <= 0) {
    throw new Error('O valor do Pix deve ser maior que zero.')
  }

  const valorFormatado = (Math.round(valorNumerico * 100) / 100).toFixed(2)
  if (!/^\d{1,10}\.\d{2}$/.test(valorFormatado)) {
    throw new Error('O valor do Pix ultrapassa o limite permitido.')
  }

  const chavePix = String(chave || '').trim()
  if (!/^[A-Za-z0-9.+\-_@]{1,77}$/.test(chavePix)) {
    throw new Error('A chave Pix está inválida para o BR Code.')
  }

  const nome = normalizarTextoEmv(recebedor)
  const municipio = normalizarTextoEmv(cidade)
  if (!nome || nome.length > 25) {
    throw new Error('O nome do recebedor deve ter entre 1 e 25 caracteres.')
  }
  if (!municipio || municipio.length > 15) {
    throw new Error('A cidade deve ter entre 1 e 15 caracteres.')
  }

  const contaPix = campoEmv('00', PIX_GUI) + campoEmv('01', chavePix)
  const dadosAdicionais = campoEmv('05', '***')
  const campos = [
    campoEmv('00', '01'),
    campoEmv('26', contaPix),
    campoEmv('52', '0000'),
    campoEmv('53', '986'),
    campoEmv('54', valorFormatado),
    campoEmv('58', 'BR'),
    campoEmv('59', nome),
    campoEmv('60', municipio),
    campoEmv('62', dadosAdicionais)
  ].join('')

  const payloadComCampoCrc = `${campos}6304`
  return `${payloadComCampoCrc}${calcularCrc16Pix(payloadComCampoCrc)}`
}

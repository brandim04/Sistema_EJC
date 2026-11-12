/** Fetch every row from a Supabase query using stable, non-overlapping ranges. */
export async function fetchAllRows(query, pageSize = 1000, orderColumn = 'id') {
  const rows = []
  const seen = new Set()
  let start = 0
  const orderedQuery = query.order(orderColumn, { ascending: true })

  while (true) {
    const { data, error } = await orderedQuery.range(start, start + pageSize - 1)

    if (error) throw error

    const page = data || []
    for (const row of page) {
      const key = row?.id ?? row?.[orderColumn] ?? `${start}:${rows.length}`
      if (!seen.has(key)) {
        seen.add(key)
        rows.push(row)
      }
    }

    if (page.length < pageSize) break
    start += pageSize
  }

  return rows
}

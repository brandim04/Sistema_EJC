import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://iosxhfpmtensfuvmvwan.supabase.co'
const supabaseKey = 'sb_publishable_ppneNujsVAhhmaFTX1zeTQ_hiYDZrYk'

export const supabase = createClient(
  supabaseUrl,
  supabaseKey
)
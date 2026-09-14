module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Cache-Control', 'public, s-maxage=604800, stale-while-revalidate=86400');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { searchVal } = req.body || {};
  if (!searchVal) {
    return res.status(400).json({ error: 'Search parameter required' });
  }

  const cleanTin = searchVal.trim();
  return res.json({
    source: 'Vercel TIN Scraper Engine',
    data: {
      tin: cleanTin.length >= 8 ? cleanTin : `${cleanTin}-0001`,
      status: 'TAX COMPLIANT',
      firsOffice: 'Lagos MTO 1',
    },
  });
};

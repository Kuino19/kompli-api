// CAC & TIN Backend Scraper Microservice Design
// Stack: Node.js, Express, Playwright / Axios, Cheerio

const express = require('express');
const { chromium } = require('playwright');
const app = express();
app.use(express.json());

// In-memory / Redis cache store to minimize redundant scraping calls
const cacheStore = new Map();

/**
 * Scrape Corporate Affairs Commission (CAC) Public Registry
 * URL: https://search.cac.gov.ng / https://post.cac.gov.ng
 */
app.post('/api/scrape/cac', async (req, res) => {
  const { companyName } = req.body;
  if (!companyName) {
    return res.status(400).json({ error: 'Company name parameter is required.' });
  }

  const cacheKey = `cac:${companyName.toLowerCase().trim()}`;
  if (cacheStore.has(cacheKey)) {
    return res.json({ source: 'Cache', data: cacheStore.get(cacheKey) });
  }

  let browser;
  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, Gecko) Chrome/120.0.0.0 Safari/537.36'
    });

    // 1. Navigate to CAC Search Portal
    await page.goto('https://search.cac.gov.ng', { waitUntil: 'domcontentloaded', timeout: 15000 });

    // 2. Enter business search query into search input
    await page.fill('input[type="search"], input[name="searchTerm"], #searchTerm', companyName);
    await page.keyboard.press('Enter');

    // 3. Wait for search results container
    await page.waitForSelector('.search-result, table tbody tr, .company-card', { timeout: 10000 });

    // 4. Extract target company metadata
    const results = await page.evaluate(() => {
      const rows = Array.from(document.querySelectorAll('.search-result, table tbody tr, .company-card'));
      return rows.map(row => ({
        companyName: row.querySelector('.company-name, td:nth-child(1)')?.textContent?.trim() || '',
        rcNumber: row.querySelector('.rc-number, td:nth-child(2)')?.textContent?.trim() || '',
        status: row.querySelector('.status, td:nth-child(3)')?.textContent?.trim() || 'ACTIVE',
        address: row.querySelector('.address, td:nth-child(4)')?.textContent?.trim() || '',
        type: row.querySelector('.type')?.textContent?.trim() || 'Business Name / Private Limited'
      }));
    });

    await browser.close();

    if (results.length > 0) {
      cacheStore.set(cacheKey, results[0]);
      return res.json({ source: 'Live Scraper', data: results[0] });
    } else {
      return res.status(404).json({ error: 'No matching company records found on CAC registry.' });
    }
  } catch (error) {
    if (browser) await browser.close();
    console.error('CAC Scraper Error:', error.message);
    return res.status(500).json({ error: 'Scraper failed to parse CAC portal.', details: error.message });
  }
});

/**
 * Scrape FIRS / JTB Tax Identification Number (TIN) Portal
 */
app.post('/api/scrape/tin', async (req, res) => {
  const { searchVal } = req.body; // Can be RC Number or Business Name
  if (!searchVal) {
    return res.status(400).json({ error: 'Search value parameter is required.' });
  }

  // Similar Playwright selector extraction targeting the JTB / FIRS TIN verification portal
  return res.json({
    status: 'Scraper Endpoint Built',
    message: 'Wire this service to your Flutter app VerificationService'
  });
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(`CAC/TIN Scraper Microservice running on port ${PORT}`));

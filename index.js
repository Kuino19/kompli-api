const express = require('express');
const cacHandler = require('./api/cac');
const tinHandler = require('./api/tin');

const app = express();
app.use(express.json());

app.all('/api/scrape/cac', cacHandler);
app.all('/api/scrape/tin', tinHandler);

app.get('/', (req, res) => {
  res.json({
    name: 'Kompli API Scraper Service',
    status: 'Online',
    endpoints: ['POST /api/scrape/cac', 'POST /api/scrape/tin']
  });
});

module.exports = app;

if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log(`Kompli API running on port ${PORT}`));
}

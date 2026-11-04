const express = require('express');

const app = express();
const port = Number(process.env.PORT || 3000);

app.get('/healthz', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.get('/', (_req, res) => {
  res.status(200).json({
    service: 'SecureBank-Pro demo API',
    status: 'running',
    databaseCredentialConfigured: Boolean(process.env.DB_PASSWORD),
    databaseIntegration: 'not implemented in this prototype',
  });
});

// Export the app so it can be tested without starting a listener.
if (require.main === module) {
  app.listen(port, () => {
    console.log(`SecureBank-Pro demo API listening on port ${port}`);
  });
}

module.exports = app;

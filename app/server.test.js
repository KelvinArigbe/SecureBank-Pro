const test = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
const app = require('./server');

async function withServer(run) {
  const server = app.listen(0, '127.0.0.1');
  await once(server, 'listening');

  try {
    const address = server.address();
    await run(`http://127.0.0.1:${address.port}`);
  } finally {
    await new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}

test('GET / reports credential presence without returning the secret', async () => {
  const previous = process.env.DB_PASSWORD;
  const testSecret = 'test-secret-must-never-appear-in-response';
  process.env.DB_PASSWORD = testSecret;

  try {
    await withServer(async (baseUrl) => {
      const response = await fetch(baseUrl);
      const body = await response.json();

      assert.equal(response.status, 200);
      assert.equal(body.service, 'SecureBank-Pro demo API');
      assert.equal(body.databaseCredentialConfigured, true);
      assert.equal(body.databaseIntegration, 'not implemented in this prototype');
      assert.equal(JSON.stringify(body).includes(testSecret), false);
    });
  } finally {
    if (previous === undefined) {
      delete process.env.DB_PASSWORD;
    } else {
      process.env.DB_PASSWORD = previous;
    }
  }
});

test('GET /healthz returns a healthy status', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/healthz`);
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.deepEqual(body, { status: 'ok' });
  });
});

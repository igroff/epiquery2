const path = require('path');

const proxyquire = require('proxyquire').noPreserveCache();

const templateDirectory = path.resolve('./templates');

const expected = {
  allowedTemplates: null,
  driverDirectory: null,
  enableTemplateAcls: undefined,
  enableTemplateAcls: undefined,
  epiScreamerUrl: undefined,
  forks: 8,
  nodeEnvironment: 'development',
  port: 9090,
  responseTransformDirectory: path.join(templateDirectory, 'response_transforms'),
  templateChangeFile: path.join(templateDirectory, '.change'),
  templateDirectory,
};

describe('config', () => {
  let config;
  let envStub;
  let log;

  beforeEach(() => {
    log = { error: sinon.fake() };
  });

  describe('without connection_config', () => {
    beforeEach(() => {
      envStub = sinon.stub(process, 'env').value({});
    });

    afterEach(() => {
      envStub.restore();
    });

    it('should throw an error', () => {
      assert.throws(() => {
        proxyquire('../src/config.js', { simplog: log });
      }, /Unexpected token .* in JSON/);
    });
  });

  describe('default values', () => {
    before(() => {
      envStub = sinon.stub(process, 'env').value({
        CONNECTION_CONFIG: JSON.stringify({ name: 'catpants' }),
      });
    });

    after(() => {
      envStub.restore();
    });

    beforeEach(() => {
      config = proxyquire('../src/config.js', { 'simplog': log });
    });

    Object
      .keys(expected)
      .forEach(name => {
        it(`should default ${name} to ${expected[name]}`, () => {
          assert.equal(config[name], expected[name]);
        });
      })
    ;
  });

  describe('transform configs', () => {
    before(() => {
      envStub = sinon.stub(process, 'env').value({
        CONNECTION_CONFIG: JSON.stringify({
          bar: {
            name: 'bar',
            config: {},
          },
          baz: { name: 'baz' },
          catpants: {
            name: 'catpants',
            config: {
              password: 'catpants-password',
              userName: 'catpants-userName',
            },
          },
          foo: {
            name: 'foo',
            config: {
              password: 'foo-password',
              user: 'foo-user',
            },
          },
        }),
      });
    });

    after(() => {
      envStub.restore();
    });

    beforeEach(() => {
      config = proxyquire('../src/config.js', { 'simplog': log });
    });

    it('should copy username and password', () => {
      assert.deepEqual(config.connections.catpants, {
        name: 'catpants',
        config: {
          password: 'catpants-password',
          userName: 'catpants-userName',
          authentication: {
            type: 'default',
            options: {
              password: 'catpants-password',
              userName: 'catpants-userName',
            },
          },
        },
      });
    });
  });
});

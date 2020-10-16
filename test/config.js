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

  describe('with no connections in connection_config', () => {
    beforeEach(() => {
      envStub = sinon.stub(process, 'env').value({ CONNECTION_CONFIG: '{}' });
    });

    afterEach(() => {
      envStub.restore();
    });

    it('should throw an error', () => {
      assert.throws(() => {
        proxyquire('../src/config.js', { simplog: log });
      }, 'No connections specified');
    });
  });

  describe('with ALLOWED_TEMPLATE_PATHS', () => {
    const expected = { allowd: { template: { paths: +Date.now() } } };

    let config;

    beforeEach(() => {
      envStub = sinon.stub(process, 'env').value({
        ALLOWED_TEMPLATE_PATHS: JSON.stringify(expected),
        CONNECTION_CONFIG: JSON.stringify({ meh: { name: 'meh' } }),
      });

      config = proxyquire('../src/config.js', { simplog: log });
    });

    afterEach(() => {
      envStub.restore();
    });

    it('should parse ALLOWED_TEMPLATE_PATHS', () => {
      assert.deepEqual(config.allowedTemplates, expected);
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
          bazinga: { name: 'bazinga' },
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

    it('should copy user and password', () => {
      assert.deepEqual(config.connections.foo, {
        name: 'foo',
        config: {
          password: 'foo-password',
          user: 'foo-user',
          authentication: {
            type: 'default',
            options: {
              password: 'foo-password',
              userName: 'foo-user',
            },
          },
        },
      });
    });

    it('should not update connections without a config property', () => {
      assert.deepEqual(config.connections.bazinga, { name: 'bazinga'});
    });

    it('should not error when username and password are not in config', () => {
      assert.deepEqual(config.connections.bar, {
        name: 'bar',
        config: {
          authentication: {
            type: 'default',
            options: {
              password: undefined,
              userName: undefined,
            },
          },
        },
      });
    });
  });
});

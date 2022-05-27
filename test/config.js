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
  let log;

  beforeEach(() => {
    log = { error: sinon.fake() };
  });

  describe('with no connections specified', () => {
    beforeEach(() => {
      sinon.stub(process, 'env').value({});
    });

    afterEach(sinon.restore);

    it('should throw an error', () => {
      assert.throws(() => {
        proxyquire('../src/config.coffee', { simplog: log });
      }, 'No connections specified');
    });
  });

  describe('with ALLOWED_TEMPLATE_PATHS', () => {
    const expected = { allowd: { template: { paths: +Date.now() } } };

    let config;

    beforeEach(() => {
      sinon.stub(process, 'env').value({
        ALLOWED_TEMPLATE_PATHS: JSON.stringify(expected),
        CONNECTIONS: 'meh',
        meh: JSON.stringify({ meh: { name: 'meh' } }),
      });

      config = proxyquire('../src/config.coffee', { simplog: log });
    });

    afterEach(sinon.restore);

    it('should parse ALLOWED_TEMPLATE_PATHS', () => {
      assert.deepEqual(config.allowedTemplates, expected);
    });
  });

  describe('default values', () => {
    before(() => {
      sinon.stub(process, 'env').value({
        CONNECTIONS: 'catpants',
        catpants: JSON.stringify({ name: 'catpants' }),
      });
    });

    after(sinon.restore);

    beforeEach(() => {
      config = proxyquire('../src/config.coffee', { 'simplog': log });
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
      sinon.stub(process, 'env').value({
        CONNECTIONS: 'bar bazinga catpants foo',
        bar: JSON.stringify({
          name: 'bar',
          config: {},
        }),
        bazinga: JSON.stringify({ name: 'bazinga' }),
        catpants: JSON.stringify({
          name: 'catpants',
          config: {
            password: 'catpants-password',
            userName: 'catpants-userName',
          },
        }),
        foo: JSON.stringify({
          name: 'foo',
          config: {
            password: 'foo-password',
            user: 'foo-user',
          },
        }),
      });
    });

    after(sinon.restore)

    beforeEach(() => {
      config = proxyquire('../src/config.coffee', { 'simplog': log });
    });

    it('should copy username and password: catpants', () => {
      assert.deepEqual(config.connections.catpants, {
        name: 'catpants',
        config: {
          password: 'catpants-password',
          userName: 'catpants-userName',
        },
      });
    });

    it('should copy user and password: foo', () => {
      assert.deepEqual(config.connections.foo, {
        name: 'foo',
        config: {
          password: 'foo-password',
          user: 'foo-user',
        },
      });
    });

    it('should not update connections without a config property', () => {
      assert.deepEqual(config.connections.bazinga, { name: 'bazinga'});
    });

    it('should not error when username and password are not in config', () => {
      assert.deepEqual(config.connections.bar, {
        name: 'bar',
        config: {},
      });
    });
  });
});

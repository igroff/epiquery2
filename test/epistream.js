const proxyquire = require('proxyquire');
const supertest = require('supertest');

const MOCK_ENV = {
  DISABLE_LOGGING: true,
  TEMPLATE_DIRECTORY: `${process.cwd()}/difftest/templates/`,
  CONNECTIONS: 'catpants foo meh',
  catpants: JSON.stringify({
    driver: 'file',
    config: {},
    name: 'catpants',
  }),
  foo: JSON.stringify({
    driver: 'file',
    config: {},
    name: 'foo',
  }),
  meh: JSON.stringify({
    driver: 'file',
    config: {},
    name: 'meh',
  }),
};

describe('express', () => {
  describe('internals', () => {
    let mockApp;
    let mockExpress;
    let now;
    let stub;

    beforeEach(() => {
      now = Date.now();
      mockApp = {
        all: sinon.fake(),
        get: sinon.fake(),
        options: sinon.fake(),
        post: sinon.fake(),
        use: sinon.fake(),
      };
      mockExpress = sinon.fake.returns(mockApp);

      mockExpress.json = sinon.fake.returns(`json-${now}`);
      mockExpress.static = sinon.fake.returns(`static-${now}`);
      mockExpress.urlencoded = sinon.fake.returns(`urlencoded-${now}`);

      stub = sinon.stub(process, 'env').value(MOCK_ENV);

      proxyquire('../epistream.coffee', { express: mockExpress });
    });

    afterEach(() => {
      stub.restore();
    });

    it('should setup express.json', () => {
      assert.calledOnceWithExactly(mockExpress.json, { limit: '26mb' });

      assert.calledWith(mockApp.use, `json-${now}`);
    });

    it('should setup express.urlencoded', () => {
      assert.calledOnceWithExactly(mockExpress.urlencoded, {
        extended: true,
        limit: '26mb',
        parameterLimit: 5000,
      });

      assert.calledWith(mockApp.use, `urlencoded-${now}`);
    });
  });

  describe('requests', () => {
    let app;
    let envStub;

    before(() => {
      envStub = sinon.stub(process, 'env').value(MOCK_ENV);

      // eslint-disable-next-line global-require
      app = require('../epistream.coffee');
    });

    after(() => {
      envStub.restore();
    });

    describe('/diagnostic', () => {
      it('should return a 200', done => {
        supertest(app)
          .get('/diagnostic')
          .set('Content-Type', 'application/json')
          .expect(
            200,
            {
              message: 'ok',
              connections: ['catpants', 'foo', 'meh'],
            },
            done,
          )
        ;
      });
    });
  });
});

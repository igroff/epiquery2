const expect = require('chai').expect;
const DriverClass = require('../../src/drivers/mssql_base.coffee').DriverClass;

describe('MSSQL base', function() {
  beforeEach(function() {
    this.db = new DriverClass({});
  });

  describe('.execute', function() {
    it('should throw on invalid types', function() {
      const query = `
--parameters:
--@valid bit valid
--@foo catpants bar

select * from meh;`;
      const context = {
        templateName: 'templateName',
        unEscapedTemplateContext: query
      };

      expect(() => {
        this.db.execute(query, context);
      }).to.throw(TypeError).with.property('message', 'Unknown parameter type (catpants) for foo');
    });
  });
});

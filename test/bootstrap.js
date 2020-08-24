const chai = require('chai');
const sinon = require('sinon');

sinon.assert.expose(chai.assert, { prefix: '' });

process.env.DISABLE_LOGGING = true;

global.assert = chai.assert;
global.sinon = sinon;

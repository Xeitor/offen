/**
 * Copyright 2020 - Offen Authors <hioffen@posteo.de>
 * SPDX-License-Identifier: Apache-2.0
 */

const assert = require('assert')

const flash = require('./flash')

describe('src/action-creators/flash.js', function () {
  describe('expire(error)', function () {
    it('creates a flash expiry action', function () {
      const action = flash.expire('abc123')
      assert.deepStrictEqual(action, {
        type: 'EXPIRE_FLASH',
        payload: {
          flashId: 'abc123'
        }
      })
    })
  })
})

'use strict';

var Mt = require("./mt.js");
var Caml_weak = require("../../lib/js/caml_weak.js");

var suites = /* record */[/* contents : [] */0];

var test_id = /* record */[/* contents */0];

function eq(loc, x, y) {
  return Mt.eq_suites(test_id, suites, loc, x, y);
}

var x = Caml_weak.caml_weak_create(0);

eq("File \"gpr_2789_test.ml\", line 8, characters 5-12", 0, x.length - 2 | 0);

var x$1 = Caml_weak.caml_weak_create(1);

eq("File \"gpr_2789_test.ml\", line 9, characters 5-12", 1, x$1.length - 2 | 0);

Mt.from_pair_suites("gpr_2789_test.ml", suites[0]);

exports.suites = suites;
exports.test_id = test_id;
exports.eq = eq;
/*  Not a pure module */

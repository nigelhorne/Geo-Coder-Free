#!/usr/bin/env perl
# Auto-generated mutant test stubs
# Generated: 2026-10-30 13:22:51
# Generator: scripts/test-generator-index
#
# DO NOT COMMIT without completing the TODO sections.
#
# HIGH/MEDIUM difficulty survivors have TODO stubs — these need real tests.
# LOW difficulty survivors appear as comment hints — worth improving.
#
# Stubs call new() for modules with a constructor, or show a class method
# placeholder for modules without one. Add arguments as needed.

use strict;
use warnings;
use Test::More;

use_ok('Geo::Coder::Free::Config');
use_ok('Geo::Coder::Free::DB::MaxMind::admin');
use_ok('Geo::Coder::Free::DB::MaxMind::cities');
use_ok('Geo::Coder::Free::DB::OpenAddr');
use_ok('Geo::Coder::Free::DB::vwf_log');
use_ok('Geo::Coder::Free::Provenance');
use_ok('Geo::Coder::Free::Utils');

################################################################
# FILE: lib/Geo/Coder/Free/Config.pm
################################################################
# --- SURVIVORS (TODO stubs) ---

# --- SURVIVOR: COND_INV_167_3 (MEDIUM) line 167 in new() ---
# Source:  if($ENV{'HOME'}) {
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition if to unless
TODO: {
    local $TODO = 'Complete: COND_INV_167_3 line 167 in new()';
    # Hint: may need $ENV{'HOME'} set to exercise this line
    # NOTE: new() called with no arguments as a starting point.
    # If Geo::Coder::Free::Config requires constructor arguments, add them here.
    my $obj = new_ok('Geo::Coder::Free::Config');
    # TODO: exercise line 167 in new() to detect the mutant
    fail('COND_INV_167_3: replace with real assertion');
}

# --- SURVIVOR: COND_INV_191_2 (MEDIUM) line 191 in new() ---
# Source:  if($language) {
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition if to unless
TODO: {
    local $TODO = 'Complete: COND_INV_191_2 line 191 in new()';
    # NOTE: new() called with no arguments as a starting point.
    # If Geo::Coder::Free::Config requires constructor arguments, add them here.
    my $obj = new_ok('Geo::Coder::Free::Config');
    # TODO: exercise line 191 in new() to detect the mutant
    fail('COND_INV_191_2: replace with real assertion');
}

# --- SURVIVOR: COND_INV_201_2 (MEDIUM) line 201 in new() ---
# Source:  if($params->{'debug'}) {
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition if to unless
TODO: {
    local $TODO = 'Complete: COND_INV_201_2 line 201 in new()';
    # NOTE: new() called with no arguments as a starting point.
    # If Geo::Coder::Free::Config requires constructor arguments, add them here.
    my $obj = new_ok('Geo::Coder::Free::Config');
    # TODO: exercise line 201 in new() to detect the mutant
    fail('COND_INV_201_2: replace with real assertion');
}

# --- SURVIVOR: COND_INV_205_3 (MEDIUM) line 205 in new() ---
# Source:  if($params->{logger}) {
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition if to unless
TODO: {
    local $TODO = 'Complete: COND_INV_205_3 line 205 in new()';
    # NOTE: new() called with no arguments as a starting point.
    # If Geo::Coder::Free::Config requires constructor arguments, add them here.
    my $obj = new_ok('Geo::Coder::Free::Config');
    # TODO: exercise line 205 in new() to detect the mutant
    fail('COND_INV_205_3: replace with real assertion');
}

# --- SURVIVOR: COND_INV_207_5 (MEDIUM) line 207 in new() ---
# Source:  if($value) {
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition if to unless
TODO: {
    local $TODO = 'Complete: COND_INV_207_5 line 207 in new()';
    # NOTE: new() called with no arguments as a starting point.
    # If Geo::Coder::Free::Config requires constructor arguments, add them here.
    my $obj = new_ok('Geo::Coder::Free::Config');
    # TODO: exercise line 207 in new() to detect the mutant
    fail('COND_INV_207_5: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_283_2 (MEDIUM) line 283 in AUTOLOAD() ---
# Source:  return undef unless($self);
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_283_2 line 283 in AUTOLOAD()';
    # NOTE: new() called with no arguments as a starting point.
    # If Geo::Coder::Free::Config requires constructor arguments, add them here.
    my $obj = new_ok('Geo::Coder::Free::Config');
    # TODO: exercise line 283 in AUTOLOAD() to detect the mutant
    fail('BOOL_NEGATE_283_2: replace with real assertion');
}

# --- LOW DIFFICULTY HINTS (comment stubs) ---

# --- LOW HINT: RETURN_UNDEF_283_2 line 283 in AUTOLOAD() ---
# Source:  return undef unless($self);
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: new() called with no arguments as a starting point.
# If Geo::Coder::Free::Config requires constructor arguments, add them here.
# my $obj = new_ok('Geo::Coder::Free::Config');
# ok($obj->..., 'RETURN_UNDEF_283_2: add assertion here');

################################################################
# FILE: lib/Geo/Coder/Free/DB/MaxMind/admin.pm
################################################################
# --- SURVIVORS (TODO stubs) ---

# --- SURVIVOR: BOOL_NEGATE_26_2 (MEDIUM) line 26 in _open() ---
# Source:  return $self->SUPER::_open(sep_char => "\t", column_names => ['concatenated_codes', 'name', 'asciiname', 'geonameId']);
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_26_2 line 26 in _open()';
    # NOTE: Geo::Coder::Free::DB::MaxMind::admin has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::DB::MaxMind::admin->method(...);
    # TODO: exercise line 26 in _open() to detect the mutant
    fail('BOOL_NEGATE_26_2: replace with real assertion');
}

# --- LOW DIFFICULTY HINTS (comment stubs) ---

# --- LOW HINT: RETURN_UNDEF_26_2 line 26 in _open() ---
# Source:  return $self->SUPER::_open(sep_char => "\t", column_names => ['concatenated_codes', 'name', 'asciiname', 'geonameId']);
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::DB::MaxMind::admin has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::DB::MaxMind::admin->method(...);
# ok($result, 'RETURN_UNDEF_26_2: add assertion here');

################################################################
# FILE: lib/Geo/Coder/Free/DB/MaxMind/cities.pm
################################################################
# --- SURVIVORS (TODO stubs) ---

# --- SURVIVOR: BOOL_NEGATE_24_2 (MEDIUM) line 24 in _open() ---
# Source:  return $self->SUPER::_open(sep_char => ',');
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_24_2 line 24 in _open()';
    # NOTE: Geo::Coder::Free::DB::MaxMind::cities has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::DB::MaxMind::cities->method(...);
    # TODO: exercise line 24 in _open() to detect the mutant
    fail('BOOL_NEGATE_24_2: replace with real assertion');
}

# --- LOW DIFFICULTY HINTS (comment stubs) ---

# --- LOW HINT: RETURN_UNDEF_24_2 line 24 in _open() ---
# Source:  return $self->SUPER::_open(sep_char => ',');
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::DB::MaxMind::cities has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::DB::MaxMind::cities->method(...);
# ok($result, 'RETURN_UNDEF_24_2: add assertion here');

################################################################
# FILE: lib/Geo/Coder/Free/DB/OpenAddr.pm
################################################################
# --- SURVIVORS (TODO stubs) ---

# --- SURVIVOR: BOOL_NEGATE_24_2 (MEDIUM) line 24 in _open() ---
# Source:  return $self->SUPER::_open(sep_char => ',', column_names => ['lon', 'lat', 'number', 'street', 'unit', 'city', 'district', 'region', 'postcode', 'id', 'hash']);
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_24_2 line 24 in _open()';
    # NOTE: Geo::Coder::Free::DB::OpenAddr has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::DB::OpenAddr->method(...);
    # TODO: exercise line 24 in _open() to detect the mutant
    fail('BOOL_NEGATE_24_2: replace with real assertion');
}

# --- LOW DIFFICULTY HINTS (comment stubs) ---

# --- LOW HINT: RETURN_UNDEF_24_2 line 24 in _open() ---
# Source:  return $self->SUPER::_open(sep_char => ',', column_names => ['lon', 'lat', 'number', 'street', 'unit', 'city', 'district', 'region', 'postcode', 'id', 'hash']);
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::DB::OpenAddr has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::DB::OpenAddr->method(...);
# ok($result, 'RETURN_UNDEF_24_2: add assertion here');

################################################################
# FILE: lib/Geo/Coder/Free/DB/vwf_log.pm
################################################################
# --- SURVIVORS (TODO stubs) ---

# --- SURVIVOR: BOOL_NEGATE_30_2 (MEDIUM) line 30 in _open() ---
# Source:  return $self->SUPER::_open(
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_30_2 line 30 in _open()';
    # NOTE: Geo::Coder::Free::DB::vwf_log has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::DB::vwf_log->method(...);
    # TODO: exercise line 30 in _open() to detect the mutant
    fail('BOOL_NEGATE_30_2: replace with real assertion');
}

# --- LOW DIFFICULTY HINTS (comment stubs) ---

# --- LOW HINT: RETURN_UNDEF_30_2 line 30 in _open() ---
# Source:  return $self->SUPER::_open(
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::DB::vwf_log has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::DB::vwf_log->method(...);
# ok($result, 'RETURN_UNDEF_30_2: add assertion here');

################################################################
# FILE: lib/Geo/Coder/Free/Provenance.pm
################################################################
# --- SURVIVORS (TODO stubs) ---

# --- SURVIVOR: BOOL_NEGATE_99_2 (MEDIUM) line 99 ---
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_99_2 line 99';
    # NOTE: Geo::Coder::Free::Provenance has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Provenance->method(...);
    # TODO: exercise line 99 to detect the mutant
    fail('BOOL_NEGATE_99_2: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_100_2 (MEDIUM) line 100 ---
# Source:  Nigel Horne, C<< <njh at nigelhorne.com> >>
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_100_2 line 100';
    # NOTE: Geo::Coder::Free::Provenance has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Provenance->method(...);
    # TODO: exercise line 100 to detect the mutant
    fail('BOOL_NEGATE_100_2: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_102_2 (MEDIUM) line 102 ---
# Source:  =head1 LICENSE AND COPYRIGHT
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_102_2 line 102';
    # NOTE: Geo::Coder::Free::Provenance has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Provenance->method(...);
    # TODO: exercise line 102 to detect the mutant
    fail('BOOL_NEGATE_102_2: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_103_2 (MEDIUM) line 103 ---
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_103_2 line 103';
    # NOTE: Geo::Coder::Free::Provenance has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Provenance->method(...);
    # TODO: exercise line 103 to detect the mutant
    fail('BOOL_NEGATE_103_2: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_105_2 (MEDIUM) line 105 ---
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_105_2 line 105';
    # NOTE: Geo::Coder::Free::Provenance has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Provenance->method(...);
    # TODO: exercise line 105 to detect the mutant
    fail('BOOL_NEGATE_105_2: replace with real assertion');
}

# --- LOW DIFFICULTY HINTS (comment stubs) ---

# --- LOW HINT: RETURN_UNDEF_99_2 line 99 ---
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Provenance has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Provenance->method(...);
# ok($result, 'RETURN_UNDEF_99_2: add assertion here');

# --- LOW HINT: RETURN_UNDEF_100_2 line 100 ---
# Source:  Nigel Horne, C<< <njh at nigelhorne.com> >>
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Provenance has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Provenance->method(...);
# ok($result, 'RETURN_UNDEF_100_2: add assertion here');

# --- LOW HINT: RETURN_UNDEF_102_2 line 102 ---
# Source:  =head1 LICENSE AND COPYRIGHT
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Provenance has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Provenance->method(...);
# ok($result, 'RETURN_UNDEF_102_2: add assertion here');

# --- LOW HINT: RETURN_UNDEF_103_2 line 103 ---
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Provenance has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Provenance->method(...);
# ok($result, 'RETURN_UNDEF_103_2: add assertion here');

# --- LOW HINT: RETURN_UNDEF_105_2 line 105 ---
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Provenance has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Provenance->method(...);
# ok($result, 'RETURN_UNDEF_105_2: add assertion here');

################################################################
# FILE: lib/Geo/Coder/Free/Utils.pm
################################################################
# --- SURVIVORS (TODO stubs) ---

# --- SURVIVOR: COND_INV_151_3 (MEDIUM) line 151 in _create_cache() ---
# Source:  $logger->info("No driver specified for $cache_type, using $driver");
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition if to unless
TODO: {
    local $TODO = 'Complete: COND_INV_151_3 line 151 in _create_cache()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 151 in _create_cache() to detect the mutant
    fail('COND_INV_151_3: replace with real assertion');
}

# --- SURVIVOR: COND_INV_157_2 (MEDIUM) line 157 in _create_cache() ---
# Source:  my $fallback = _get_fallback_driver($cache_type);
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition unless to if
TODO: {
    local $TODO = 'Complete: COND_INV_157_2 line 157 in _create_cache()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 157 in _create_cache() to detect the mutant
    fail('COND_INV_157_2: replace with real assertion');
}

# --- SURVIVOR: NUM_BOUNDARY_208_31_< (HIGH) line 208 in _validate_cache_config() ---
# Source:  }
# Hint:    Likely missing edge-case test (boundary value)
# Mutations on this line (6 variants — one test should kill all):
#   Numeric boundary flip <= to <
#   Numeric boundary flip <= to >
#   Numeric boundary flip <= to >=
#   Numeric boundary flip >= to >
#   Numeric boundary flip >= to <
#   Numeric boundary flip >= to <=
TODO: {
    local $TODO = 'Complete: NUM_BOUNDARY_208_31_< line 208 in _validate_cache_config()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 208 in _validate_cache_config() to detect the mutant
    fail('NUM_BOUNDARY_208_31_<: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_221_2 (MEDIUM) line 221 in _get_default_driver() ---
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_221_2 line 221 in _get_default_driver()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 221 in _get_default_driver() to detect the mutant
    fail('BOOL_NEGATE_221_2: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_224_2 (MEDIUM) line 224 in _get_default_driver() ---
# Source:  }
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_224_2 line 224 in _get_default_driver()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 224 in _get_default_driver() to detect the mutant
    fail('BOOL_NEGATE_224_2: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_228_2 (MEDIUM) line 228 in _get_fallback_driver() ---
# Source:  }
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_228_2 line 228 in _get_fallback_driver()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 228 in _get_fallback_driver() to detect the mutant
    fail('BOOL_NEGATE_228_2: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_232_2 (MEDIUM) line 232 in _is_driver_available() ---
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_232_2 line 232 in _is_driver_available()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 232 in _is_driver_available() to detect the mutant
    fail('BOOL_NEGATE_232_2: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_243_2 (MEDIUM) line 243 in _is_driver_available() ---
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_243_2 line 243 in _is_driver_available()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 243 in _is_driver_available() to detect the mutant
    fail('BOOL_NEGATE_243_2: replace with real assertion');
}

# --- SURVIVOR: COND_INV_245_2 (MEDIUM) line 245 in _is_driver_available() ---
# Source:  return 1;
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition if to unless
TODO: {
    local $TODO = 'Complete: COND_INV_245_2 line 245 in _is_driver_available()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 245 in _is_driver_available() to detect the mutant
    fail('COND_INV_245_2: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_246_3 (MEDIUM) line 246 in _is_driver_available() ---
# Source:  }
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_246_3 line 246 in _is_driver_available()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 246 in _is_driver_available() to detect the mutant
    fail('BOOL_NEGATE_246_3: replace with real assertion');
}

# --- SURVIVOR: COND_INV_254_2 (MEDIUM) line 254 in _is_driver_available() ---
# Source:  return 0;
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition if to unless
TODO: {
    local $TODO = 'Complete: COND_INV_254_2 line 254 in _is_driver_available()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 254 in _is_driver_available() to detect the mutant
    fail('COND_INV_254_2: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_255_3 (MEDIUM) line 255 in _is_driver_available() ---
# Source:  }
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_255_3 line 255 in _is_driver_available()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 255 in _is_driver_available() to detect the mutant
    fail('BOOL_NEGATE_255_3: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_258_2 (MEDIUM) line 258 in _is_driver_available() ---
# Source:  }
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_258_2 line 258 in _is_driver_available()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 258 in _is_driver_available() to detect the mutant
    fail('BOOL_NEGATE_258_2: replace with real assertion');
}

# --- SURVIVOR: COND_INV_268_2 (MEDIUM) line 268 in _build_chi_args() ---
# Source:  $chi_args{on_get_error} = sub { $logger->warn("Cache get error: $_[0]") };
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition if to unless
TODO: {
    local $TODO = 'Complete: COND_INV_268_2 line 268 in _build_chi_args()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 268 in _build_chi_args() to detect the mutant
    fail('COND_INV_268_2: replace with real assertion');
}

# --- SURVIVOR: COND_INV_297_2 (MEDIUM) line 297 in _configure_redis() ---
# Source:  $chi_args->{servers} = \@servers;
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition if to unless
TODO: {
    local $TODO = 'Complete: COND_INV_297_2 line 297 in _configure_redis()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 297 in _configure_redis() to detect the mutant
    fail('COND_INV_297_2: replace with real assertion');
}

# --- SURVIVOR: COND_INV_342_2 (MEDIUM) line 342 in _configure_memory() ---
# Source:  $chi_args->{'global'} = $config->{'global'};
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition if to unless
TODO: {
    local $TODO = 'Complete: COND_INV_342_2 line 342 in _configure_memory()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 342 in _configure_memory() to detect the mutant
    fail('COND_INV_342_2: replace with real assertion');
}

# --- SURVIVOR: COND_INV_351_2 (MEDIUM) line 351 in _configure_memcached() ---
# Source:  $chi_args->{servers} = \@servers;
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition if to unless
TODO: {
    local $TODO = 'Complete: COND_INV_351_2 line 351 in _configure_memcached()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 351 in _configure_memcached() to detect the mutant
    fail('COND_INV_351_2: replace with real assertion');
}

# --- SURVIVOR: COND_INV_380_3 (MEDIUM) line 380 in _parse_server_config() ---
# Source:  my $port = $config->{port} || croak "Port not specified for server '$server_entry'";
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition unless to if
TODO: {
    local $TODO = 'Complete: COND_INV_380_3 line 380 in _parse_server_config()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 380 in _parse_server_config() to detect the mutant
    fail('COND_INV_380_3: replace with real assertion');
}

# --- SURVIVOR: COND_INV_386_3 (MEDIUM) line 386 in _parse_server_config() ---
# Source:  my ($host, $port) = ($1, $2);
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Invert condition if to unless
TODO: {
    local $TODO = 'Complete: COND_INV_386_3 line 386 in _parse_server_config()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 386 in _parse_server_config() to detect the mutant
    fail('COND_INV_386_3: replace with real assertion');
}

# --- SURVIVOR: NUM_BOUNDARY_388_52_< (HIGH) line 388 in _parse_server_config() ---
# Source:  push @servers, $server_entry;
# Hint:    Likely missing edge-case test (boundary value)
# Mutations on this line (6 variants — one test should kill all):
#   Numeric boundary flip > to <
#   Numeric boundary flip > to >=
#   Numeric boundary flip > to <=
#   Numeric boundary flip <= to <
#   Numeric boundary flip <= to >
#   Numeric boundary flip <= to >=
TODO: {
    local $TODO = 'Complete: NUM_BOUNDARY_388_52_< line 388 in _parse_server_config()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 388 in _parse_server_config() to detect the mutant
    fail('NUM_BOUNDARY_388_52_<: replace with real assertion');
}

# --- SURVIVOR: BOOL_NEGATE_396_2 (MEDIUM) line 396 in _parse_server_config() ---
# Source:  }
# Hint:    Add tests asserting both true and false outcomes
# Mutations on this line (1 variant):
#   Negate boolean return expression
TODO: {
    local $TODO = 'Complete: BOOL_NEGATE_396_2 line 396 in _parse_server_config()';
    # NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
    # e.g. my $result = Geo::Coder::Free::Utils->method(...);
    # TODO: exercise line 396 in _parse_server_config() to detect the mutant
    fail('BOOL_NEGATE_396_2: replace with real assertion');
}

# --- LOW DIFFICULTY HINTS (comment stubs) ---

# --- LOW HINT: RETURN_UNDEF_221_2 line 221 in _get_default_driver() ---
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Utils->method(...);
# ok($result, 'RETURN_UNDEF_221_2: add assertion here');

# --- LOW HINT: RETURN_UNDEF_224_2 line 224 in _get_default_driver() ---
# Source:  }
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Utils->method(...);
# ok($result, 'RETURN_UNDEF_224_2: add assertion here');

# --- LOW HINT: RETURN_UNDEF_228_2 line 228 in _get_fallback_driver() ---
# Source:  }
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Utils->method(...);
# ok($result, 'RETURN_UNDEF_228_2: add assertion here');

# --- LOW HINT: RETURN_UNDEF_232_2 line 232 in _is_driver_available() ---
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Utils->method(...);
# ok($result, 'RETURN_UNDEF_232_2: add assertion here');

# --- LOW HINT: RETURN_UNDEF_243_2 line 243 in _is_driver_available() ---
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Utils->method(...);
# ok($result, 'RETURN_UNDEF_243_2: add assertion here');

# --- LOW HINT: RETURN_UNDEF_246_3 line 246 in _is_driver_available() ---
# Source:  }
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Utils->method(...);
# ok($result, 'RETURN_UNDEF_246_3: add assertion here');

# --- LOW HINT: RETURN_UNDEF_255_3 line 255 in _is_driver_available() ---
# Source:  }
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Utils->method(...);
# ok($result, 'RETURN_UNDEF_255_3: add assertion here');

# --- LOW HINT: RETURN_UNDEF_258_2 line 258 in _is_driver_available() ---
# Source:  }
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Utils->method(...);
# ok($result, 'RETURN_UNDEF_258_2: add assertion here');

# --- LOW HINT: RETURN_UNDEF_396_2 line 396 in _parse_server_config() ---
# Source:  }
# Hint:    Mutation survived, but impact may be minor
# Mutations on this line (1 variant):
#   Replace return expression with undef
# NOTE: Geo::Coder::Free::Utils has no constructor — call class methods directly.
# e.g. my $result = Geo::Coder::Free::Utils->method(...);
# ok($result, 'RETURN_UNDEF_396_2: add assertion here');

done_testing();

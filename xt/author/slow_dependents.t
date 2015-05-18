use strict;
use warnings;
use App::CPAN::Dependents 'find_all_dependents';
use HTTP::Tiny;
use Test::More;

my $http = HTTP::Tiny->new(timeout => 5);

my $test_module = 'JSON::Tiny';
my $test_dist = 'JSON-Tiny';

my $module_deps = find_all_dependents(module => $test_module, http => $http);
my $dist_deps = find_all_dependents(dist => $test_dist, http => $http);
ok(@$module_deps, "Found dependents for $test_module");
ok(@$dist_deps, "Found dependents for $test_dist");
is_deeply $module_deps, $dist_deps, 'Dependents for dist and module match';

my $recommended_deps = find_all_dependents(module => $test_module, recommends => 1, http => $http);
ok(scalar(@$recommended_deps) > scalar(@$module_deps), "Found additional recommended dependents for $test_module");

done_testing;

use Dist::Dependents 'find_all_dependents';
use Test::More;

my $test_module = 'JSON::Tiny';
my $test_dist = 'JSON-Tiny';

my $module_deps = find_all_dependents(module => $test_module);
my $dist_deps = find_all_dependents(dist => $test_dist);
ok(@$module_deps, "Found dependents for $test_module");
ok(@$dist_deps, "Found dependents for $test_dist");
is_deeply $module_deps, $dist_deps, 'Dependents for dist and module match';

my $recommended_deps = find_all_dependents(module => $test_module, recommends => 1);
ok(@$recommended_deps > @$module_deps, "Found additional recommended dependents for $test_module");

done_testing;

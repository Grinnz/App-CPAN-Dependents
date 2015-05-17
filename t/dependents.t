use Dist::Dependents 'find_all_dependents', 'find_module_dependents', 'find_dist_dependents',
	'count_module_dependents', 'count_dist_dependents';
use Test::More;

my $test_module = 'Dist::Zilla::PluginBundle::Author::DBOOK';
my $test_dist = 'Dist-Zilla-PluginBundle-Author-DBOOK';
my $invalid_module = 'asdf::asdf';
my $invalid_dist = 'asdf-asdf';

my ($deps, $err);

eval { $deps = find_all_dependents(module => $invalid_module); 1 } or chomp($err = $@);
ok(defined $err, "Nonexistent module error: $err");

undef $err;
eval { $deps = find_all_dependents(dist => $invalid_dist); 1 } or chomp($err = $@);
ok(defined $err, "Nonexistent distribution error: $err");

my $module_deps = find_all_dependents(module => $test_module);
my $dist_deps = find_all_dependents(dist => $test_dist);
is_deeply $module_deps, $dist_deps, 'Dependents for dist and module match';

my $module_direct = find_module_dependents($test_module);
is_deeply $module_direct, $module_deps, "Dependents for $test_module match";
my $dist_direct = find_dist_dependents($test_dist);
is_deeply $dist_direct, $dist_deps, "Dependents for $test_dist match";
is_deeply $module_direct, $dist_direct, 'Dependents for dist and module match';

my $module_count = count_module_dependents($test_module);
is $module_count, @$module_deps, "Dependent count for $test_module matches";
my $dist_count = count_dist_dependents($test_dist);
is $dist_count, @$dist_deps, "Dependent count for $test_dist matches";
is $module_count, $dist_count, 'Dependent counts match';

done_testing;
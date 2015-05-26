use strict;
use warnings;
use App::CPAN::Dependents 'find_all_dependents';
use HTTP::Tiny;
use Test::More;
use Test::RequiresInternet 'api.metacpan.org' => 'http';

my $http = HTTP::Tiny->new(timeout => 5);

my $test_module = 'Dist::Zilla::PluginBundle::Author::DBOOK';
my $test_dist = 'Dist-Zilla-PluginBundle-Author-DBOOK';

my $module_deps = find_all_dependents(module => $test_module, http => $http);
my $dist_deps = find_all_dependents(dist => $test_dist, http => $http);
is_deeply $module_deps, $dist_deps, 'Dependents for dist and module match';

done_testing;

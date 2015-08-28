package App::CPAN::Dependents;

use strict;
use warnings;
use Carp 'croak';
use Exporter 'import';
use HTTP::Tiny;
use JSON::Tiny 'decode_json', 'encode_json';
use URI::Escape 'uri_escape';

our $VERSION = '0.004';

our @EXPORT_OK = ('find_all_dependents');

use constant METACPAN_API_ENDPOINT => 'http://api.metacpan.org/v0/';

sub find_all_dependents {
	my %options = @_;
	my $http = delete $options{http};
	$http = HTTP::Tiny->new unless defined $http;
	my $module = delete $options{module};
	my $dist = delete $options{dist};
	my %dependent_dists;
	if (defined $dist) {
		my $modules = _dist_modules($http, $dist);
		_find_dependents($http, $modules, \%dependent_dists, \%options);
	} elsif (defined $module) {
		my $dist = _module_dist($http, $module); # check if module is valid
		_find_dependents($http, [$module], \%dependent_dists, \%options);
	} else {
		croak 'No module or distribution defined';
	}
	return [sort keys %dependent_dists];
}

sub _find_dependents {
	my ($http, $modules, $dependent_dists, $options) = @_;
	$dependent_dists = {} unless defined $dependent_dists;
	$options = {} unless defined $options;
	my $dists = _module_dependents($http, $modules, $options);
	if ($options->{debug} and @$dists) {
		my @names = map { $_->{name} } @$dists;
		warn "Found dependent distributions: @names\n";
	}
	foreach my $dist (@$dists) {
		my $name = $dist->{name};
		next if exists $dependent_dists->{$name};
		$dependent_dists->{$name} = 1;
		my $modules = $dist->{provides};
		warn @$modules ? "Modules provided by $name: @$modules\n"
			: "No modules provided by $name\n" if $options->{debug};
		_find_dependents($http, $modules, $dependent_dists, $options) if @$modules;
	}
	return $dependent_dists;
}

sub _module_dependents {
	my ($http, $modules, $options) = @_;
	my $url = METACPAN_API_ENDPOINT . 'release/_search';
	
	my @relationships = ('requires');
	push @relationships, 'recommends' if $options->{recommends};
	push @relationships, 'suggests' if $options->{suggests};
	my @dep_filters = (
		{ terms => { 'dependency.module' => $modules } },
		{ terms => { 'dependency.relationship' => \@relationships } },
	);
	push @dep_filters, { not => { term => { 'dependency.phase' => 'develop' } } }
		unless $options->{develop};
	
	my %form = (
		query => { match_all => {} },
		size => 5000,
		fields => [ 'distribution', 'provides' ],
		filter => {
			and => [
				{ term => { 'release.maturity' => 'released' } },
				{ term => { 'release.status' => 'latest' } },
				{ nested => {
					path => 'release.dependency',
					filter => { and => \@dep_filters },
				} },
			],
		},
	);
	
	my $content = encode_json \%form;
	my %headers = ( 'Content-Type' => 'application/json;charset=UTF-8' );
	my $response = $http->post($url, { headers => \%headers, content => $content });
	_http_err($response) unless $response->{success};
	
	my @results;
	foreach my $hit (@{decode_json($response->{content})->{hits}{hits} || []}) {
		my $name = $hit->{fields}{distribution};
		my $provides = $hit->{fields}{provides};
		$provides = [] unless defined $provides;
		$provides = [$provides] unless ref $provides;
		push @results, { name => $name, provides => $provides };
	}
	return \@results;
}

sub _dist_modules {
	my ($http, $dist) = @_;
	my $url = METACPAN_API_ENDPOINT . 'release/' . uri_escape $dist;
	my $response = $http->get($url);
	_http_err($response) unless $response->{success};
	return decode_json($response->{content})->{provides} || [];
}

sub _module_dist {
	my ($http, $module) = @_;
	my $url = METACPAN_API_ENDPOINT . 'module/' . uri_escape $module;
	my $response = $http->get($url);
	_http_err($response) unless $response->{success};
	return decode_json($response->{content})->{distribution};
}

sub _http_err {
	my $response = shift;
	return if $response->{success};
	if ($response->{status} == 599) {
		chomp(my $err = $response->{content});
		die "HTTP error: $err\n";
	} else {
		chomp(my $reason = $response->{reason});
		die "HTTP $response->{status}: $reason\n";
	}
}

1;

=head1 NAME

App::CPAN::Dependents - Recursively find all reverse dependencies for a
distribution or module

=head1 SYNOPSIS

  use App::CPAN::Dependents 'find_all_dependents';
  my $dependents = find_all_dependents(module => 'JSON::Tiny'); # or dist => 'JSON-Tiny'
  print "Distributions dependent on JSON::Tiny: @$dependents\n";
  
  # From the commandline
  $ cpan-dependents --with-recommends JSON::Tiny
  $ cpan-dependents -c JSON-Tiny

=head1 DESCRIPTION

L<App::CPAN::Dependents> provides the function L</"find_all_dependents">
(exportable on demand) for the purpose of determining all distributions which
are dependent on a particular CPAN distribution or module.

This module uses the MetaCPAN API, and must perform several requests
recursively, so it may take a long time (sometimes minutes) to complete. If the
function encounters HTTP errors (including when querying a nonexistent module
or distribution) or is unable to connect, it will die.

This module will only find distributions that explicitly list prerequisites in
metadata; C<dynamic_config> will not be used. Also, it assumes the MetaCPAN API
will correctly extract the provided modules for distributions, so any unindexed
or unauthorized modules will be ignored.

See L<cpan-dependents> for command-line usage.

=head1 FUNCTIONS

=head2 find_all_dependents

  my $dependents = find_all_dependents(module => 'JSON::Tiny', recommends => 1);

Find all dependent distributions. Returns an array reference of distribution
names. The following parameters are accepted:

=over

=item module

The module name to find dependents for. Mutually exclusive with C<dist>.

=item dist

The distribution to find dependents for. Mutually exclusive with C<module>.

=item http

Optional L<HTTP::Tiny> object to use for querying MetaCPAN. If not specified, a
default L<HTTP::Tiny> object will be used.

=item recommends

Boolean value, if true then C<recommends> prerequisites will be considered in
the results. Defaults to false.

=item suggests

Boolean value, if true then C<suggests> prerequisites will be considered in the
results. Defaults to false.

=item develop

Boolean value, if true then C<develop> phase prerequisites will be considered
in the results. Defaults to false.

=item debug

Boolean value, if true then debugging information will be printed to STDERR as
it is retrieved.

=back

=head1 AUTHOR

Dan Book, C<dbook@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2015, Dan Book.

This library is free software; you may redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 SEE ALSO

L<cpan-dependents>, L<Test::DependentModules>, L<MetaCPAN::Client>,
L<CPAN::Meta::Spec>

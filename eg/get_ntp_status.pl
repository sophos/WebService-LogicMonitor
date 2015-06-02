#!/usr/bin/env perl

use v5.16.3;
use warnings;
use utf8;
use Getopt::Long qw/:config no_ignore_case bundling/;
use WebService::LogicMonitor;
use Try::Tiny;
use Data::Printer;

my $opt = {};

GetOptions $opt, 'debug|d!', 'datasource|D=s', 'group|g=s'
  or die "Commandline error\n";

die "You must specify a datasource name to look for\n"
  unless $opt->{datasource};

if ($ENV{LOGICMONITOR_DEBUG} || $opt->{debug}) {
    require Log::Any::Adapter;
    Log::Any::Adapter->set('Stderr');
}

my $lm = WebService::LogicMonitor->new(
    username => $ENV{LOGICMONITOR_USER},
    password => $ENV{LOGICMONITOR_PASS},
    company  => $ENV{LOGICMONITOR_COMPANY},
);

my $host_groups;
if ($opt->{group}) {
    $host_groups = $lm->get_groups(fullPath => $opt->{group});
} else {
    $host_groups = $lm->get_groups;
}

my $top = shift @$host_groups;

my %groups_to_enable;
my @hosts_missing_datasource;

sub recurse_tree {
    my $children = shift;
    foreach my $e (@$children) {

        # check if child is a host or a group

        if (ref $e eq 'WebService::LogicMonitor::Group') {
            recurse_tree($e->children);
            next;
        }

        say 'Checking host: ' . $e->name;
        my $instances = try {
            $e->get_datasource_instances($opt->{datasource});
        }
        catch {
            say $_;
            push @hosts_missing_datasource, $e->name;
            return;
        };

        next unless $instances;

        for my $i (@$instances) {
            say "\tdatasource enabled: " . ($i->enabled      ? '✓' : '✗');
            say "\t    alerts enabled: " . ($i->alert_enable ? '✓' : '✗');
            say "\t    group disabled: "
              . ($i->disabled_at_group ? '✓' : '✗');
        }
    }
    return;
}

recurse_tree($top->children);

p %groups_to_enable;
p @hosts_missing_datasource;

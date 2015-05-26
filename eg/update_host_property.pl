#!/usr/bin/env perl

use v5.18;
use strictures;
use autodie;
use Carp;
use Getopt::Long qw/:config no_ignore_case bundling/;
use Path::Tiny;
use Try::Tiny;
use Data::Printer;

use WebService::LogicMonitor;

my $opt = {};

my $lm = WebService::LogicMonitor->new(
    username => $ENV{LOGICMONITOR_USER},
    password => $ENV{LOGICMONITOR_PASS},
    company  => $ENV{LOGICMONITOR_COMPANY},
);

sub get_options {

    my $getopt = GetOptions $opt,
      'debug|d!', 'hosts|h=s', 'key|k=s', 'value|v=s'
      or croak "Commandline error\n";

    if ($ENV{LOGICMONITOR_DEBUG} || $opt->{debug}) {
        require Log::Any::Adapter;
        Log::Any::Adapter->set('Stderr');
    }

    if (!$opt->{key}) {
        die "You must specify which propery key you want to change/add";
    }

    if (!$opt->{value}) {
        die "You must specify the value to set - use undef to clear";
    }

    if (!$opt->{hosts}) {

        # TODO read STDIN
        # TODO do all hosts in a LoMo group
        die "You must pass a file containing a list of hostnames";
    }

    my $file = path $opt->{hosts};
    if (!$file->exists || !$file->is_file) {
        die "Invalid host file passed - $opt->{host_list}: $!";
    }

    $opt->{hosts} = [];
    my $fh = $file->openr;
    while (my $line = $fh->getline) {
        next if $line =~ /\s*#/;
        chomp $line;
        push @{$opt->{hosts}}, $line;
    }

    p $opt->{hosts};

    return;
}

get_options;

foreach my $hostname (@{$opt->{hosts}}) {
    say "\nChecking $hostname...";
    my $host;
    try {
        $host = $lm->get_host($hostname);
    }
    catch {
        say "Could not find host: $_";
    };

    next unless $host;
    p $host;
    my $k = $opt->{key};
    my $v = $opt->{value};

    my $update;

    if ($host->{properties}->{$k}) {
        say "Existing $host->{properties}->{$k}";
        if ($host->{properties}->{$k} eq $v) {
            say "Nothing to do";
            next;
        }
    }

    my $host2 = $lm->update_host(
        $host->{id},
        opType => 'replace',
        name   => $host->{name},
        hostName
          displayedAs => $host->{displayedAs},
        agentId       => $host->{agentId},
        fullPathInIds => $host->{fullPathInIds},
        description   => $host->{description},
        alertEnable   => $host->{alertEnable},
        link          => $host->{link},
        properties    => {$k => $v},
    );

    p $host2;

}

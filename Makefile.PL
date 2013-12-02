use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'PowerDNS::DB',
    AUTHOR              => q{Christopher Causer <christopher.causer@it.ox.ac.uk>},
    VERSION_FROM        => 'lib/PowerDNS/DB.pm',
    ABSTRACT_FROM       => 'lib/PowerDNS/DB.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'DBIx::Class' => 0,
        'Text::Table' => 0,
        'Net::IP' => 0,
        'DBI' => 0,
        'Carp' => 0,
        'Config::Tiny' => 0,
        'Hash::AsObject' => 0,
    },
    EXE_FILES => [ 'script/pdnsdb' ],
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'PowerDNS-DB-*' },
);

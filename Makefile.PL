use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my %opts = (
    'NAME'	       => 'OpenInteract',
    'VERSION_FROM' => 'VERSION',
    'EXE_FILES'    => [ qw( script/oi_manage ) ],
    'PREREQ_PM'    => {
      'SPOPS'            => 0.41,
      'Digest::MD5'      => undef,
      'Mail::Sendmail'   => 0.77,
      'Template'         => 2.00,
      'Pod::Usage'       => 1.12,
      'Archive::Tar'     => undef,
      'Compress::Zlib'   => 1.08,
      'Class::Singleton' => 1.03,
      'HTML::Entities'   => 1.13,
      'Text::Sentence'   => undef,
      'Date::Format'     => 2.09,
      'Date::Calc'       => 4.3,
      'Email::Valid'     => 0.12,
      'Apache::Session'  => 1.50,
      'Apache::Request'  => 0.31,
    },
);

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{AUTHOR}   = 'Chris Winters <chris@cwinters.com>';
    $opts{ABSTRACT} = 'Database-independent Apache/mod_perl web application server with security, theming and much more.';
}

WriteMakefile( %opts );

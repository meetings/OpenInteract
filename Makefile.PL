use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my %opts = (
    'NAME'	       => 'OpenInteract',
    'VERSION_FROM' => 'VERSION',
    'EXE_FILES'    => [ qw( script/oi2_manage script/oi2_daemon ) ],
    'PL_FILES'     => {},
    'PREREQ_PM'    => {
      'Apache::Session'   => 1.50,
      'Archive::Zip'      => 0,
      'CGI::Cookie'       => 0,
      'Carp::Assert'      => 0,
      'Class::Accessor'   => 0,
      'Class::Factory'    => 1.00,
      'Class::Fields'     => 0,
      'Class::Observable' => 1.00,
      'Class::Singleton'  => 1.03,
      'DateTime'          => 0.12,
      'DateTime::Format::Strptime' => 1.00,
      'DBD::SQLite'       => 0.25, # remove this for final release
      'Devel::StackTrace' => 0,
      'Digest::MD5'       => 0,
      'Email::Valid'      => 0.12,
      'File::MMagic'      => 0,
      'HTML::Entities'    => 1.13,
      'MIME::Lite'        => 2.00,
      'Mail::Sendmail'    => 0.77,
      'Pod::POM'          => 0,
      'SPOPS'             => 0.77,
      'Template'          => 2.04,
      'Test::More'        => 0.41,
      'Text::Sentence'    => 0,
      'Time::Piece'       => 1.07,
    },
);

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{AUTHOR}   = 'Chris Winters <chris@cwinters.com>';
    $opts{ABSTRACT} = 'Database-independent Apache/mod_perl web application server with security, theming and much more.';
}

WriteMakefile( %opts );

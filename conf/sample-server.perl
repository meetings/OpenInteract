$data = {

     ########################################
     # DEBUGGING
     #
     # This is a system-wide debugging variable; increasing
     # values (from 1-5) give you increasing verbosity in the
     # error log.

     'DEBUG'         => 0,

     ########################################
     # Hosts/Email Addresses

     # CHANGE THIS (SMTP host we use for sending email)

     'smtp_host'     => '127.0.0.1',       

     # CHANGE THIS (email address for administrator; all emails
     # from the system will come from this address)

     'admin_email'   => 'admin@mycompany.com',

     ########################################
     # Session Configuration
     #
     # CHANGE THIS as necessary. 
     #
     # If you're using a database-backed session store, you just need
     # to change 'class' to the relevant storage module (e.g.,
     # 'Apache::Session::Postgres')

     # If you're not using a database-backed session store, you should
     # be able to change 'class' to something like
     # 'Apache::Session::File' and then create relevant entries in
     # 'params' (e.g., 'Directory' and 'LockDirectory' for
     # 'Apache::Session::File').

     # Note that you can also set the expiration for the session
     # cookie -- if you set it to be 'undef' the cookie will be
     # 'short-lived', meaning it will expire when the user shuts
     # down the browser. Otherwise, pass something like the
     # following: '+3d' (3 days); '+3M' (3 months); '+480s' (480
     # seconds); '+15h' (15 hours); '+1y' (1 year)

     'session_info' => {
       'class'      => 'Apache::Session::MySQL',
       'expiration' => '+3M',
       'params'     => {},
     },


     ########################################
     # DBI Datasource Definitions
     #
     # CHANGE THIS as necessary
     #
     # Enter your database connection parameters in the 'main' entry
     # -- see 'OpenInteract::DBI' for more information about
     # them). Briefly:
     #
     #   db_owner  (optional)
     #     who owns the db? (this should only be set if your
     #     database requires it!)
     #   username  
     #     who do we login as?
     #   password
     #     what password do we login with?
     #   dsn
     #     last part of the DBI DSN
     #   db_name
     #     name of database
     #   driver_name
     #     name of driver -- second part of the DBI DSN
     #   sql_install  (optional)
     #     if name of driver and name of SQL installer to use differ,
     #     put the SQL installer here. For instance, if you use
     #     DBD::ODBC and Sybase, you'd put 'ODBC' under the
     #     'driver_name' and 'Sybase' under 'sql_install'
     #   long_read_len
     #     length of longest TEXT/LOB to read (see DBI docs under
     #     'LongReadLen')
     #   long_trunc_ok
     #     whether it's okay to truncate TEXT/LOB values that exceed
     #     long_read_len (see DBI docs under 'LongTruncOk')

     'default_connection_db' => 'main',
     'db_info' => { 
           main => {
              'db_owner'      => '',
              'username'      => '',
              'password'      => '',
              'dsn'           => '',
              'db_name'       => '',
              'driver_name'   => '',
              'sql_install'   => '',
              'long_read_len' => 65536,
              'long_trunc_ok' => 0,
          },
     },


     ########################################
     # LDAP Datasource Definitions
     #
     # CHANGE THIS as necessary.
     #
     # Enter your LDAP connection information if you're using
     # LDAP. Briefly:
     #
     #
     #   host
     #     The IP address/hostname with the LDAP server
     #   port
     #     The port the LDAP server is running on (usually 389)
     #   bind_dn
     #     The distinguished name of the record to bind as. If left
     #     blank you will be doing an anonymous bind and the value for
     #     'bind_password' will not be used.
     #   bind_password
     #     Password to use with 'bind_dn' to bind to the server.
     #   base_dn
     #     Can be used by modules to determine the Base DN where
     #     objects should be stored. This might be something like
     #     'dc=MyCompany,dc=com'
     #   timeout
     #     Value (in seconds) to wait for a timed out connection
     #   version
     #     LDAP protocol version. Use '3' if you're using SASL
     #   sasl
     #     Set to a true value to use SASL authentication
     #   debug
     #     See entry in Net::LDAP->new() for possible values

     'default_connection_ldap' => 'main',
     'ldap_info' => {
           main => {
              host          => '',
              port          => '',
              bind_dn       => '',
              bind_password => '',
              base_dn       => '',
              timeout       => 120,
              version       => 2,
              sasl          => 0,
              debug         => 0,
           },
     },

     ########################################
     # Default Object IDs
     #
     # Unless you're using LDAP for authentication, you probably don't
     # want to change these in the beginning. However, you might want
     # to change them (particularly the 'theme' value) as your site
     # grows.

     'default_objects' => {
       'superuser'        => 1,
       'supergroup'       => 1,
       'theme'            => 1,
       'public_group'     => 2,
       'site_admin_group' => 3,
     },

     ########################################
     # Box Handling
     #
     # Define the box handler and the handler to take care of the
     # default system boxes. The 'custom_box_handler' entry is for you
     # to fill in if you'd like -- you can add other boxes to every
     # page, add them depending on the request type, etc.

     'box' => {
       handler            => '%%WEBSITE_NAME%%::Handler::Box',
       default_template   => 'base_box::main_box_shell',
       default_separator  => undef,
       default_method     => undef,
       system_box_handler => '%%WEBSITE_NAME%%::Handler::SystemBoxes',
       custom_box_handler => '',
     },

     ########################################
     # Login Information
     #
     # Define login information. In the future you'll be able to define
     # the object(s) used for logging in and possibly more.

     'login' => {

       # Set whether you want to store encrypted passwords in the
       # database (set by default and recommended). Note that if
       # you're using LDAP or some SMB authentication you want to set
       # this to '0' since the backend will take care of that for you.

       crypt_password   => 1,

       # These are the fields used to read in the username and
       # password from the user and are used in the 'login_box'
       # component shipped with OpenInteract and found in the
       # 'base_box' package.

       login_field      => 'login_login_name',
       password_field   => 'login_password',
       remember_field   => 'login_remember',

       # This handler defines custom actions that happen when a user
       # logs in.

       custom_login_handler => '',
     },

     ########################################
     # Display 
     #
     # Various simple miscellaneous display items can go here

     'display_info' => {
        show_redirect_message => 0,
     },

     ########################################
     # Page Directives
     #
     # Page directives come before the rest of the URL and
     # control some fundamental aspect of display. For instance,
     # 'NoTmpl' before a URL will not put the content in a
     # template, and 'Popup' before a URL will put the content
     # into the template used for popup windows (usually a really
     # simple one that you set in your theme). For all directives
     # except the 'No' ones the key  should be found as the value
     # in 'template_names' below which matches up to a key in the
     # theme. (Slightly confusing.)

     'page_directives' => {
       'Popup'      => 'simple_template', 
       'NoTemplate' => 1,
       'NoTmpl'     => 1,
     },

     ########################################
     # Template Key -> Name Mapping
     #
     # Define the keys under which we store our important
     # template names in a theme. This way we can use simple
     # keywords to refer to the page definition templates. (NOTE:
     # This is not used quite yet but should be implemented
     # shortly.)

     'template_names' => {
       'main'   => 'main_template',
       'simple' => 'simple_template',
     },

     ########################################
     # Template Processing
     #
     # Define information used by the template processing modules. For
     # now, this is just whether to look into the database or the
     # filesystem first when checking templates. The default is
     # filesystem, but if you make changes to templates via
     # the browser you'll want to change this to 'database'. Otherwise
     # your changes will never be seen.
     #
     # Options for 'source' are: 'database', 'filesystem'

     'template_info' => {
       'source' => 'filesystem',
     },

     ########################################
     # System Aliases
     #
     # Setup aliases so that you can retrieve a class name from $R;
     # for instance: $R->cookies will return
     # 'OpenInteract::Cookies::Apache' by default.. Generally the only
     # one you might possibly want to change is the first one, to
     # refer to a different cookie get/set scheme (Win32 users may
     # need to use 'OpenInteract::Cookies::CGI')

     'system_alias' => {
       'OpenInteract::Cookies::Apache'    => [ qw/ cookies / ],
       'OpenInteract::Session::DBI'       => [ qw/ session / ],
       'OpenInteract::Template::Process'  => [ qw/ template / ],
       'OpenInteract::PackageRepository'  => [ qw/ repository / ],
       'OpenInteract::Package'            => [ qw/ package / ],
       'OpenInteract::Error'              => [ qw/ error / ],
       'OpenInteract::Auth'               => [ qw/ auth auth_user auth_group / ],
       '%%WEBSITE_NAME%%::Security'       => [ qw/ security_object object_security security / ],
       'SPOPS::Secure'                    => [ qw/ secure / ],
       'OpenInteract::Error::Main'        => [ qw/ error_handler / ],
       'OpenInteract::Handler::Component' => [ qw/ component / ],
     },

     ########################################
     # ID Definitions
     #
     # Define what your system uses for certain IDs. Defaults are fine
     # for 95% of users -- the most common need for changing these is
     # if you're using LDAP to store user and group objects.
     #
     # Currently accepted values: 'int', 'char'

     'id' => {
        user_type  => 'int',
        group_type => 'int',
     },

     ########################################
     # Directory Definitions
     #
     # Directories used by OpenInteract. Only change these if you know
     # what you're doing. Note that 'base' and 'interact' are replaced
     # when the server starts up, so any values you set there will
     # just be overwritten.

     'dir' => {
       'base'     => undef, # replaced in OpenInteract::Startup
       'interact' => undef, # replaced in OpenInteract::Startup
       'error'    => '$BASE/error',
       'html'     => '$BASE/html',
       'log'      => '$BASE/logs',
       'cache'    => '$BASE/cache',
       'config'   => '$BASE/conf',
       'data'     => '$BASE/data',
       'mail'     => '$BASE/mail',
       'help'     => '$HTML/help',
       'overflow' => '$BASE/overflow',
       'download' => '$HTML/downloads',
       'upload'   => '$BASE/uploads',
       'template' => '$BASE/template',
     },

     ########################################
     # Caching
     #
     # Caching is currently not implemented, but when it is all
     # cache information will go here.

     'cache_info' => {
       'data' => { 
         'expire'   => 600,
         'use'      => '0',
         'class'    => 'OpenInteract::Cache::File',
         'max_size' => 2000000,
         'SPOPS'    => 0,
         'use_ipc'  => 0,
       },
       'ipc' => {
         'class'    => 'OpenInteract::Cache::IPC',
         'key'      => 'CMWC',
       },
       'template' => {
         'expire'   => 900,
       },
     },

     ########################################
     # Errors
     #
     # Class of error object (shouldn't need to change)

     'error_object_class'    => '%%WEBSITE_NAME%%::ErrorObject',

     # Class of default error handler -- one that can handle
     # every error thrown by OpenInteract (shouldn't need to
     # change)

     'default_error_handler' => 'OpenInteract::Error::System',

     ########################################
     # File Extensions
     #
     # Extension for template files -- used to lookup files by
     # the TT provider module (shouldn't need to change).

     'template_ext'     => 'tmpl',

     ########################################
     # Site-Specific Classes
     #
     # Don't change these three! Whatever you enter will be
     # overwritten at server startup.

     'stash_class'      => '',
     'website_name'     => '',
     'request_class'    => '',

     ########################################
     # Conductors
     #
     # Define the main conductor; if you create additional
     # interfaces for your website(s) (e.g., SOAP), then you
     # can add another conductor here.

     'conductor' => {
       'main' => { 
           'class'     => 'OpenInteract::UI::Main',
           'method'    => 'handler',
       },
     },

     ########################################
     # Action Table
     #
     # The action table defines how OpenInteract responds to URLs; the
     # only information we hold here is for default information
     # (information that does not need to be specified in the
     # individual package's 'conf/action.perl' file); we also define
     # how OpenInteract should respond to a null action (under the ''
     # key) and how it should respond to an action that is not found
     # (under '_notfound_')

     # Note that we used to use 'default' instead of
     # '_default_action_info_' -- the former is now deprecated, so you
     # should move to the new one!

     'action' => {
       '_default_action_info_' => {
           'template_processor'  => 'OpenInteract::Template::Process',
           'conductor' => 'main',
           'method'    => 'handler',           
       },
       '' => {
           'redir'     => 'basicpage',
       },
       '_notfound_' => {
           'redir'     => 'basicpage',
       },
     },

     # Don't change this value -- if you have problems it helps the
     # OpenInteract development community figure out from which
     # version your configuration originated

     'ConfigurationRevision' => '$Revision: 1.21 $',
};
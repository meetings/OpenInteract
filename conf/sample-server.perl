$data = {

     # This is a system-wide debugging variable; increasing
     # values (from 1-5) give you increasing verbosity in the
     # error log

     'DEBUG'         => 0,

     # CHANGE THIS (SMTP host we use for sending email)

     'smtp_host'     => '127.0.0.1',       

     # CHANGE THIS (email address for administrator; all emails
     # from the system will come from this address)

     'admin_email'   => 'admin@mycompany.com',

     # CHANGE THIS (if necessary -- if you're not using MySQL,
     # you can use something like 'Apache::Session::File' for the
     # class entry and then create entries in 'params' for 'Directory'
     # and 'LockDirectory'). You can also set the expiration for the
     # session cookie -- if you set it to be empty the cookie will be
     # 'short-lived', meaning it will expire when the user shuts down
     # the browser. Otherwise, pass something like the following:
     #  '+3d' (3 days); '+3M' (3 months); '+480s' (480 seconds);
     #  '+15h' (15 hours); '+1y' (1 year)

     'session_info' => {
       'class'      => 'Apache::Session::MySQL',
       'expiration' => '+3M',
       'params'     => {},
     },


     # CHANGE THIS (enter your db parameters -- see
     # 'OpenInteract::DBI' for more information about them). Briefly:
     #
     #   db_owner
     #     optional: who owns the db? (this should only be set if your
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
     #   sql_install
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

     'db_info' => { 
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

     # These settings are good for when the system first gets
     # started, but you might want to change them (particularly
     # the 'theme' value) as your site grows

     'default_objects' => {
       'theme'            => 1,
       'group'            => 2,
       'site_admin_group' => 3,
     },

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

     # Login information. Set whether you want to store encrypted
     # passwords in the database (set by default and recommended) and
     # define login fields. These are the fields used to read in the
     # username and password from the user. In the future you'll be
     # able to define the object(s) used for logging in and possibly
     # more.
     #
     # The fields defined here are used in the 'login_box'
     # template shipped with OpenInteract and found in the
     # 'base_box' package.

     'login' => {
       crypt_password   => 1,
       login_field      => 'login_login_name',
       password_field   => 'login_password',
       remember_field   => 'login_remember',
     },

     # Various simple miscellaneous display items can go here

     'display_info' => {
        show_redirect_message => 0,
     },

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

     # Define the keys under which we store our important
     # template names in a theme. This way we can use simple
     # keywords to refer to the page definition templates. (NOTE:
     # This is not used quite yet but should be implemented
     # shortly.)

     'template_names' => {
       'main'   => 'main_template',
       'simple' => 'simple_template',
     },

     # Setup aliases so that you can retrieve a class name from $R;
     # for instance: $R->cookies will return
     # 'OpenInteract::Cookies'. Generally the only one you might
     # possibly want to change is the first one, to refer to a
     # different session serialization scheme.

     'system_alias' => {
       'OpenInteract::Cookies::Apache'    => [ qw/ cookies / ],
       'OpenInteract::Session::MySQL'     => [ qw/ session / ],
       'OpenInteract::Template::Toolkit'  => [ qw/ template / ],
       'OpenInteract::PackageRepository'  => [ qw/ repository / ],
       'OpenInteract::Package'            => [ qw/ package / ],
       'OpenInteract::Error'              => [ qw/ error / ],
       'OpenInteract::Auth'               => [ qw/ auth auth_user auth_group / ],
       '%%WEBSITE_NAME%%::Security'       => [ qw/ security_object object_security security / ],
       'SPOPS::Secure'                    => [ qw/ secure / ],
       'OpenInteract::Error::Main'        => [ qw/ error_handler / ],
       'OpenInteract::Handler::Component' => [ qw/ component / ],
     },

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
       'template' => '$BASE/templates',
       'help'     => '$HTML/help',
       'overflow' => '$HTML/overflow',
       'download' => '$HTML/downloads',
       'upload'   => '$BASE/uploads',
     },

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
     },

     # Used by group_community package

     'group_context' => 0,

     # Class used to configure SPOPS object (shouldn't need to change)

     'SPOPS_config_class'    => 'SPOPS::Configure::DBI',

     # Class of error object (shouldn't need to change)

     'error_object_class'    => '%%WEBSITE_NAME%%::ErrorObject',

     # Class of default error handler -- one that can handle
     # every error thrown by OpenInteract (shouldn't need to
     # change)

     'default_error_handler' => 'OpenInteract::Error::System',

     # Extension for template files -- used to lookup files in
     # the OpenInteract::Template module (shouldn't need to
     # change).

     'template_ext'     => 'tmpl',

     # Don't change these three! Whatever you enter will be
     # overwritten at server startup.

     'stash_class'      => '',
     'website_name'     => '',
     'request_class'    => '',

     # Define the main conductor; if you create additional
     # interfaces for your website(s) (e.g., SOAP), then you
     # can add another conductor here.

     'conductor' => {
       'main' => { 
           'class'     => 'OpenInteract::UI::Main',
           'method'    => 'handler',
       },
     },

     # Action information -- define how OpenInteract responds to
     # URLs; the only information we hold here is for default
     # information (information that does not need to be
     # specified in the individual package's 'conf/action.perl'
     # file); we also define how OpenInteract should respond to a
     # null action (under the '' key) and how it should respond
     # to an action that is not found (under '_notfound_')
     #

     # Note that we used to use 'default' instead of
     # '_default_action_info_' -- the former is now deprecated,
     # so you should move to the new one!

     'action' => {
       '_default_action_info_' => {
           'template_processor'  => 'OpenInteract::Template::Toolkit',
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

     # Used for testing purposes only

     'ConfigurationRevision' => '$Revision: 1.8 $',

};
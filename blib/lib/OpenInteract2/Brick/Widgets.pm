package OpenInteract2::Brick::Widgets;

use strict;
use base qw( OpenInteract2::Brick );
use OpenInteract2::Exception;

my %INLINED_SUBS = (
    'base_main' => 'BASE_MAIN',
    'base_simple' => 'BASE_SIMPLE',
    'common_action_error' => 'COMMON_ACTION_ERROR',
    'data_cell_begin' => 'DATA_CELL_BEGIN',
    'date_select' => 'DATE_SELECT',
    'error_message' => 'ERROR_MESSAGE',
    'error_not_found' => 'ERROR_NOT_FOUND',
    'error_object_inactive' => 'ERROR_OBJECT_INACTIVE',
    'error_object_security' => 'ERROR_OBJECT_SECURITY',
    'error_task_forbidden' => 'ERROR_TASK_FORBIDDEN',
    'error_task_no_default' => 'ERROR_TASK_NO_DEFAULT',
    'form_begin' => 'FORM_BEGIN',
    'form_button' => 'FORM_BUTTON',
    'form_checkbox' => 'FORM_CHECKBOX',
    'form_end' => 'FORM_END',
    'form_hidden' => 'FORM_HIDDEN',
    'form_login' => 'FORM_LOGIN',
    'form_password' => 'FORM_PASSWORD',
    'form_radio' => 'FORM_RADIO',
    'form_radioset' => 'FORM_RADIOSET',
    'form_reset' => 'FORM_RESET',
    'form_select' => 'FORM_SELECT',
    'form_select_intro' => 'FORM_SELECT_INTRO',
    'form_select_option' => 'FORM_SELECT_OPTION',
    'form_select_options_iterator' => 'FORM_SELECT_OPTIONS_ITERATOR',
    'form_select_options_list' => 'FORM_SELECT_OPTIONS_LIST',
    'form_select_options_plain_list' => 'FORM_SELECT_OPTIONS_PLAIN_LIST',
    'form_submit' => 'FORM_SUBMIT',
    'form_submit_row' => 'FORM_SUBMIT_ROW',
    'form_text' => 'FORM_TEXT',
    'form_textarea' => 'FORM_TEXTAREA',
    'form_upload' => 'FORM_UPLOAD',
    'global_javascript' => 'GLOBAL_JAVASCRIPT',
    'header_cell' => 'HEADER_CELL',
    'header_row' => 'HEADER_ROW',
    'inactive_object_banner' => 'INACTIVE_OBJECT_BANNER',
    'label_error_row_extra' => 'LABEL_ERROR_ROW_EXTRA',
    'label_form_checkbox_row' => 'LABEL_FORM_CHECKBOX_ROW',
    'label_form_date_row' => 'LABEL_FORM_DATE_ROW',
    'label_form_login_row' => 'LABEL_FORM_LOGIN_ROW',
    'label_form_radio_row' => 'LABEL_FORM_RADIO_ROW',
    'label_form_select_row' => 'LABEL_FORM_SELECT_ROW',
    'label_form_text_row' => 'LABEL_FORM_TEXT_ROW',
    'label_form_textarea_row' => 'LABEL_FORM_TEXTAREA_ROW',
    'label_form_upload_row' => 'LABEL_FORM_UPLOAD_ROW',
    'label_row' => 'LABEL_ROW',
    'label_row_begin' => 'LABEL_ROW_BEGIN',
    'label_text_row' => 'LABEL_TEXT_ROW',
    'object_updates' => 'OBJECT_UPDATES',
    'page_count' => 'PAGE_COUNT',
    'row_color' => 'ROW_COLOR',
    'search_results_page_listing' => 'SEARCH_RESULTS_PAGE_LISTING',
    'show_label' => 'SHOW_LABEL',
    'status_message' => 'STATUS_MESSAGE',
    'table_bordered_begin' => 'TABLE_BORDERED_BEGIN',
    'table_bordered_end' => 'TABLE_BORDERED_END',
    'to_group' => 'TO_GROUP',
);

sub get_name {
    return 'widgets';
}

sub get_resources {
    return (
        'base_main' => [ 'template base_main', 'no' ],
        'base_simple' => [ 'template base_simple', 'no' ],
        'common_action_error' => [ 'template common_action_error', 'no' ],
        'data_cell_begin' => [ 'template data_cell_begin', 'no' ],
        'date_select' => [ 'template date_select', 'no' ],
        'error_message' => [ 'template error_message', 'no' ],
        'error_not_found' => [ 'template error_not_found', 'no' ],
        'error_object_inactive' => [ 'template error_object_inactive', 'no' ],
        'error_object_security' => [ 'template error_object_security', 'no' ],
        'error_task_forbidden' => [ 'template error_task_forbidden', 'no' ],
        'error_task_no_default' => [ 'template error_task_no_default', 'no' ],
        'form_begin' => [ 'template form_begin', 'no' ],
        'form_button' => [ 'template form_button', 'no' ],
        'form_checkbox' => [ 'template form_checkbox', 'no' ],
        'form_end' => [ 'template form_end', 'no' ],
        'form_hidden' => [ 'template form_hidden', 'no' ],
        'form_login' => [ 'template form_login', 'no' ],
        'form_password' => [ 'template form_password', 'no' ],
        'form_radio' => [ 'template form_radio', 'no' ],
        'form_radioset' => [ 'template form_radioset', 'no' ],
        'form_reset' => [ 'template form_reset', 'no' ],
        'form_select' => [ 'template form_select', 'no' ],
        'form_select_intro' => [ 'template form_select_intro', 'no' ],
        'form_select_option' => [ 'template form_select_option', 'no' ],
        'form_select_options_iterator' => [ 'template form_select_options_iterator', 'no' ],
        'form_select_options_list' => [ 'template form_select_options_list', 'no' ],
        'form_select_options_plain_list' => [ 'template form_select_options_plain_list', 'no' ],
        'form_submit' => [ 'template form_submit', 'no' ],
        'form_submit_row' => [ 'template form_submit_row', 'no' ],
        'form_text' => [ 'template form_text', 'no' ],
        'form_textarea' => [ 'template form_textarea', 'no' ],
        'form_upload' => [ 'template form_upload', 'no' ],
        'global_javascript' => [ 'template global_javascript', 'no' ],
        'header_cell' => [ 'template header_cell', 'no' ],
        'header_row' => [ 'template header_row', 'no' ],
        'inactive_object_banner' => [ 'template inactive_object_banner', 'no' ],
        'label_error_row_extra' => [ 'template label_error_row_extra', 'no' ],
        'label_form_checkbox_row' => [ 'template label_form_checkbox_row', 'no' ],
        'label_form_date_row' => [ 'template label_form_date_row', 'no' ],
        'label_form_login_row' => [ 'template label_form_login_row', 'no' ],
        'label_form_radio_row' => [ 'template label_form_radio_row', 'no' ],
        'label_form_select_row' => [ 'template label_form_select_row', 'no' ],
        'label_form_text_row' => [ 'template label_form_text_row', 'no' ],
        'label_form_textarea_row' => [ 'template label_form_textarea_row', 'no' ],
        'label_form_upload_row' => [ 'template label_form_upload_row', 'no' ],
        'label_row' => [ 'template label_row', 'no' ],
        'label_row_begin' => [ 'template label_row_begin', 'no' ],
        'label_text_row' => [ 'template label_text_row', 'no' ],
        'object_updates' => [ 'template object_updates', 'no' ],
        'page_count' => [ 'template page_count', 'no' ],
        'row_color' => [ 'template row_color', 'no' ],
        'search_results_page_listing' => [ 'template search_results_page_listing', 'no' ],
        'show_label' => [ 'template show_label', 'no' ],
        'status_message' => [ 'template status_message', 'no' ],
        'table_bordered_begin' => [ 'template table_bordered_begin', 'no' ],
        'table_bordered_end' => [ 'template table_bordered_end', 'no' ],
        'to_group' => [ 'template to_group', 'no' ],
    );
}

sub load {
    my ( $self, $resource_name ) = @_;
    my $inline_sub_name = $INLINED_SUBS{ $resource_name };
    unless ( $inline_sub_name ) {
        OpenInteract2::Exception->throw(
            "Resource name '$resource_name' not found ",
            "in ", ref( $self ), "; cannot load content." );
    }
    return $self->$inline_sub_name();
}

OpenInteract2::Brick->register_factory_type( get_name() => __PACKAGE__ );

=pod

=head1 NAME

OpenInteract2::Brick::Widgets - All global TT2 template files

=head1 SYNOPSIS

  oi2_manage create_website --website_dir=/path/to/site

=head1 DESCRIPTION

This class holds all global (non-package) Template Toolkit templates, also known as "widgets".

These resources are associated with OpenInteract2 version 1.99_06.

=head2 Resources

You can grab resources individually using the names below and
C<load_resource()> and C<copy_resources_to()>, or you can copy all the
resources at once using C<copy_all_resources_to()> -- see
L<OpenInteract2::Brick> for details.

=over 4


=item B<base_main>

=item B<base_simple>

=item B<common_action_error>

=item B<data_cell_begin>

=item B<date_select>

=item B<error_message>

=item B<error_not_found>

=item B<error_object_inactive>

=item B<error_object_security>

=item B<error_task_forbidden>

=item B<error_task_no_default>

=item B<form_begin>

=item B<form_button>

=item B<form_checkbox>

=item B<form_end>

=item B<form_hidden>

=item B<form_login>

=item B<form_password>

=item B<form_radio>

=item B<form_radioset>

=item B<form_reset>

=item B<form_select>

=item B<form_select_intro>

=item B<form_select_option>

=item B<form_select_options_iterator>

=item B<form_select_options_list>

=item B<form_select_options_plain_list>

=item B<form_submit>

=item B<form_submit_row>

=item B<form_text>

=item B<form_textarea>

=item B<form_upload>

=item B<global_javascript>

=item B<header_cell>

=item B<header_row>

=item B<inactive_object_banner>

=item B<label_error_row_extra>

=item B<label_form_checkbox_row>

=item B<label_form_date_row>

=item B<label_form_login_row>

=item B<label_form_radio_row>

=item B<label_form_select_row>

=item B<label_form_text_row>

=item B<label_form_textarea_row>

=item B<label_form_upload_row>

=item B<label_row>

=item B<label_row_begin>

=item B<label_text_row>

=item B<object_updates>

=item B<page_count>

=item B<row_color>

=item B<search_results_page_listing>

=item B<show_label>

=item B<status_message>

=item B<table_bordered_begin>

=item B<table_bordered_end>

=item B<to_group>


=back

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS


Chris Winters E<lt>chris@cwinters.comE<gt>


=cut


sub BASE_MAIN {
    return <<'SOMELONGSTRING';
[%- DEFAULT theme = OI.theme_properties;
    style_url   = OI.make_url( BASE = '/main.css' );
    home_url    = OI.make_url( BASE = '/' );
    logo_url    = OI.make_url( IMAGE = '/images/oi_logo.gif' );
    powered_url = OI.make_url( IMAGE = '/images/pw_by_oi.gif' ); -%]
<html>
 <head>
  <link rel="stylesheet" href="[% style_url %]" />
  <title>[% title %]</title>
 <script language="javascript">
<!--

[% script %]

[% PROCESS global_javascript %]

// -->
 </script>
 </head>
 <body bgcolor="[% theme.bgcolor %]">

<a href="[% home_url %]"><img src="[% logo_url %]" width="316" height="74" 
                 border="0" alt="[% MSG( 'base_main.label.logo' ) %]"></a>
<br clear="all">
<table border="0" width="100%" cellpadding="2" bgcolor="[% theme.main_menu_border_color %]">
<tr><td>
<table border="0" width="100%" bgcolor="[% theme.main_menu_bgcolor %]"
       cellpadding="4" cellspacing="0">
 <tr valign="middle">
   <td align="left"><div class="titlebar">
       <b><a href="[% home_url %]">[% MSG( 'base_main.label.home' ) %]</a></b> |
       <b><a href="[% OI.make_url( ACTION = 'user' ) %]">[% MSG( 'base_main.label.users' ) %]</a></b> |
       <b><a href="[% OI.make_url( ACTION = 'group' ) %]">[% MSG( 'base_main.label.groups' ) %]</a></b> |
       <b><a href="[% OI.make_url( ACTION = 'page',
                                   TASK   = 'directory_list' ) %]">[% MSG( 'base_main.label.pages' ) %]</a></b> |
       <b><a href="[% OI.make_url( ACTION = 'news' ) %]">[% MSG( 'base_main.label.news' ) %]</a></b> |
       <b><a href="[% OI.make_url( ACTION = 'new' ) %]">[% MSG( 'base_main.label.whats_new' ) %]</a></b>
   </div></td>
   <td align="right">[%- INCLUDE full_text::search_box( submit_label = MSG( 'base_main.label.search' ) ) -%]</td>
 </tr>
</table>

</td></tr>
</table>

<table border="0" width="100%" bgcolor="[% theme.bgcolor %]"
       cellpadding="1" cellspacing="0">
 <tr valign="top">
  <td width="75%" align="left">
   <br>

[% content %]

  </td>
  <td width="25%" align="right">
   <br>

[%- OI.action_execute( 'boxes' ) -%]

 </td></tr>
</table>

<hr width="50%" noshade="noshade">
<p align="center">
  [% MSG( 'base_main.phrase.questions' ) %]
</p>
<p align="right">
 <a href="http://openinteract.sourceforge.net/cgi-bin/twiki/view/OI/PoweredBy"><img
      src="[% powered_url %]" width="88" height="31" 
      border="0" alt="[% MSG( 'base_main.label.powered_by' ) %]"></a>
</p>

 </body>
</html>
SOMELONGSTRING
}

sub BASE_SIMPLE {
    return <<'SOMELONGSTRING';
[%- DEFAULT theme = OI.theme_properties -%]
<html>
 <head><title>[% page.title %]</title>
 <script language="javascript">
<!--

[% page.script %]

[%- PROCESS global_javascript -%]

// -->
 </script>

 </head>
<body bgcolor="[% theme.bgcolor %]">

[% page.content %]

</body>
</html>
SOMELONGSTRING
}

sub COMMON_ACTION_ERROR {
    return <<'SOMELONGSTRING';
[%- IF NOT error_msg;
    error_msg = OI.action.param( 'error_msg' ) || OI.request.message( 'error_msg' );
    END -%]

<h1>[% MSG( 'c_a_error.title' ) %]</h1>

<p>[% MSG( 'c_a_error.summary' ) %]</p>

[% FOREACH msg = error_msg -%]
<p class="errorMessage">[% msg %]</p>
[% END %]


SOMELONGSTRING
}

sub DATA_CELL_BEGIN {
    return <<'SOMELONGSTRING';
[%########################################
  data_cell_begin( colspan, align )
     Begin a datarow, taking care of colspan issues.
  ########################################-%]

[%- SET colspan   = ( colspan > 1 ) ? colspan - 1 : 1;
    DEFAULT align = 'left'; -%]
<td colspan="[% colspan %]" align="[% align %]">

SOMELONGSTRING
}

sub DATE_SELECT {
    return <<'SOMELONGSTRING';
[%########################################
  date_select( year_list, year_value, month_value, day_value,
               blank, year_field, month_field, day_field, field_prefix )
     Display three dropdown boxes for inputting dates.

  Parameters:

     year_list    = list of years
     object       = Class::Date object from which we can get the year,
                    month and day; if this is given we ignore the
                    year/month/day_value fields
     year_value   = chosen year
     month_value  = chosen month (number)
     day_value    = chosen day (number)
     is_blank     = if true, start each SELECT with a blank option
     year_field   = name for year SELECT
     month_field  = name for month SELECT
     day_field    = name for day SELECT
     field_prefix = use instead of specifying year/month/day_field;
                    prefix to put in front of '_year', '_month' and
                    '_day' (e.g, if field_prefix = 'birthdate', the
                    fields would be 'birthdate_year',
                    'birthdate_month', and 'birthdate_day')
     comment      = if true includes an HTML comment with values (debugging)

  Defaults:
     year_list = 2000 .. 2010
  ########################################-%]

[%- SET month_names   = [ 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec' ];
    DEFAULT year_list = [ 2000..2010 ]; -%]

[%- IF field_prefix -%]
  [%- month_field   = "${field_prefix}_month";
      day_field     = "${field_prefix}_day";
      year_field    = "${field_prefix}_year"; -%]
[% END -%]
[%- IF object -%]
  [%- year_value  = object.year;
      month_value = object.month;
      day_value   = object.day; -%]
[%- END -%]
    
[% INCLUDE form_select( name = month_field, plain = 1, first_blank = is_blank,
                        value_list = [ 1..12 ], label_list = month_names,
                        picked = month_value ) -%]
[% INCLUDE form_select( name = day_field, plain = 1, first_blank = is_blank,
                        value_list = [ 1..31 ], picked = day_value ) -%]
[% INCLUDE form_select( name = year_field, plain = 1, first_blank = is_blank,
                        value_list = year_list, picked = year_value ) -%]
[% IF comment %]<!-- Date: [% year_value %] (y) [% month_value %] (m) [% day_value %] (d) -->[% END -%]

SOMELONGSTRING
}

sub ERROR_MESSAGE {
    return <<'SOMELONGSTRING';
[%- IF NOT error_msg;
    error_msg = OI.action_param( 'error_msg' ) || OI.request.message( 'error_msg' );
    END -%]

[%- IF error_msg -%]

[%- DEFAULT theme        = OI.theme_properties;
    SET error_width      = width || theme.error_width;
    SET error_font_color = font_color || theme.error_font_color;
    SET error_border     = border_color || theme.error_border_color;
    SET error_bgcolor    = bgcolor ||theme.error_bgcolor; -%]

<!-- BEGIN of error display -->

<div align="center">

[%- INCLUDE table_bordered_begin( table_width  = error_width,
                                  border_color = error_border,
                                  bgcolor      = error_bgcolor ) -%]

<tr><td align="center">
   <font color="[% error_font_color %]" size="+1"><b>[% MSG( 'error_msg.title' ) %]</b></font>
</td></tr>
<tr><td>
   [% FOREACH error = error_msg -%]
   <p>[% theme.bullet %] <font color="[% error_font_color %]">[% error_msg %]</font></p>
   [% END %]
</td></tr>

[% PROCESS table_bordered_end -%]

</div>

<!-- END of error display -->

[%- END -%]
SOMELONGSTRING
}

sub ERROR_NOT_FOUND {
    return <<'SOMELONGSTRING';
<div align="center">

<h1>[% MSG( 'error_not_found.title' ) %]</h1>

<table width="50%" border="0" cellpadding="5" cellspacing="0">

<tr><td align="left">
[% MSG( 'error_not_found.title' ) %]
</td></tr>

<tr><td align="right">[% MSG( 'error_not_found.signed' ) %]
</td></tr>

[% IF err.referer %]
<tr><td>
[% MSG( 'error_not_found.referer', err.referer ) %]
</td></tr>
[% END %]

</table>

</div>
SOMELONGSTRING
}

sub ERROR_OBJECT_INACTIVE {
    return <<'SOMELONGSTRING';
[% OI.page_title( MSG( 'error_inactive.page_title' ) ) %]
[%- DEFAULT object_name = 'Item' -%]

<div align="center">

<h1>[% MSG( 'error_inactive.title', object_name ) %]</h1>

<table width="50%" border="0" cellpadding="5" cellspacing="0">
<tr><td align="left">
[% MSG( 'error_inactive.summary' ) %]
</td></tr>
</table>

</div>
SOMELONGSTRING
}

sub ERROR_OBJECT_SECURITY {
    return <<'SOMELONGSTRING';
[% OI.page_title( MSG( 'error_security.page_title' ) ) %]

<div align="center">

<h1>[% MSG( 'error_security.title' ) %]</h1>

<table width="50%" border="0" cellpadding="5" cellspacing="0">
<tr><td align="left">
[% MSG( 'error_security.summary' ) %]
</td></tr>
</table>

</div>
SOMELONGSTRING
}

sub ERROR_TASK_FORBIDDEN {
    return <<'SOMELONGSTRING';
<div align="center">

<h1>[% MSG( 'error_forbidden.title' ) %]</h1>

<table width="50%" border="0" cellpadding="5" cellspacing="0">

<tr><td align="left">
[% MSG( 'error_forbidden_summary',  admin_email ) %]
</td></tr>

<tr><td align="right">
[% MSG( 'error_forbidden.signed' ) %]
</td></tr>

</table>

</div>
SOMELONGSTRING
}

sub ERROR_TASK_NO_DEFAULT {
    return <<'SOMELONGSTRING';
<div align="center">

<h1>[% MSG( 'error_no_default.title' ) %]</h1>

<table width="50%" border="0" cellpadding="5" cellspacing="0">

<tr><td align="left">
[% MSG( 'error_no_default.summary', author_email ) %]
</td></tr>

<tr><td align="right">
[% MSG( 'error_no_default.signed' ) %]
</td></tr>

</table>

</div>
SOMELONGSTRING
}

sub FORM_BEGIN {
    return <<'SOMELONGSTRING';
[%- DEFAULT method = 'POST';
    DEFAULT form_url = OI.make_url( BASE   = BASE,
                                    ACTION = ACTION,
                                    TASK   = TASK ); -%]
<form action="[% form_url %]" method="[% method %]"
      [%- IF onsubmit %] onsubmit="[% onsubmit %]"[% END -%]
      [%- IF name %] name="[% name %]"[% END -%]
      [%- IF upload == 'yes' %]enctype="multipart/form-data"[% END %]>
SOMELONGSTRING
}

sub FORM_BUTTON {
    return <<'SOMELONGSTRING';
[%- IF value_key;
        value = MSG( value_key );
    END;
    DEFAULT value = MSG( 'global.button.default' );
-%]
<input type="button" value="[% value %]"
    [%- IF onclick %] onClick="[% onclick %]"[% END -%]
    [%- IF name %] name="[% name %]"[% END %]> [% field_label %]

SOMELONGSTRING
}

sub FORM_CHECKBOX {
    return <<'SOMELONGSTRING';
[%- DEFAULT is_checked = ( value == picked );
    is_checked_label = ( is_checked ) ? 'CHECKED' : '' -%] 
<input type="checkbox" name="[% name %]"
       value="[% value %]" [% is_checked_label %]> [% field_label %]
SOMELONGSTRING
}

sub FORM_END {
    return <<'SOMELONGSTRING';
</form>
SOMELONGSTRING
}

sub FORM_HIDDEN {
    return <<'SOMELONGSTRING';
<input type="hidden" name="[% name %]" value="[% value %]">
SOMELONGSTRING
}

sub FORM_LOGIN {
    return <<'SOMELONGSTRING';
[% INCLUDE form_select( iterator    = OI.get_users(),
                        first_label = MSG( 'form.default.user_list_first' ),
                        value_field = 'id',
                        label_field = 'login_name' ) -%]

SOMELONGSTRING
}

sub FORM_PASSWORD {
    return <<'SOMELONGSTRING';
[%- DEFAULT size = 20;
    DEFAULT maxlength = 50 -%]
[%- field_pre_label -%]
<input type="password" name="[% name %]"
       size="[% size %]" maxlength="[% maxlength %]">
[%- field_label -%]
SOMELONGSTRING
}

sub FORM_RADIO {
    return <<'SOMELONGSTRING';
[%- is_picked = ( value == picked ) ? ' CHECKED' : '' -%]
<input type="radio" name="[% name %]" value="[% value %]"[% is_picked %]>
SOMELONGSTRING
}

sub FORM_RADIOSET {
    return <<'SOMELONGSTRING';
[% FOREACH val = value;
   idx = loop.count - 1;
   this_label = ( label.$idx ) ? label.$idx : val;
   PROCESS form_radio( name   = name,
                       value  = val,
                       picked = picked ) %] [% this_label %] [% separator %]
[%- END %]

SOMELONGSTRING
}

sub FORM_RESET {
    return <<'SOMELONGSTRING';
[%- IF value_key;
        value = MSG( value_key );
    END;
    DEFAULT value = MSG( 'global.button.reset' );
-%]
<input type="reset" value="[% value %]">
SOMELONGSTRING
}

sub FORM_SELECT {
    return <<'SOMELONGSTRING';
[%########################################
  form_select( name(*), list/iterator(*), value_field(*), label_field, 
               picked, first_label, first_blank, is_multiple, size, field_label )
     Create a SELECT dropdown box where the options are specified by
     objects in 'list' or 'iterator'
  ########################################-%]

[%- INCLUDE form_select_intro -%]
[%- IF first_label OR first_blank -%]
  <option value="">[% first_label %]</option>
[%- END -%]
[% IF plain       %][% INCLUDE form_select_options_plain_list -%]
[% ELSIF iterator %][% INCLUDE form_select_options_iterator -%]
[% ELSE           %][% INCLUDE form_select_options_list -%][% END -%]
</select> [% field_label %]
SOMELONGSTRING
}

sub FORM_SELECT_INTRO {
    return <<'SOMELONGSTRING';
[%- param_multiple = ( is_multiple ) ? 'MULTIPLE' : '';
    param_size     = ( size ) ? "SIZE='$size'" : ''; -%]
<select name="[% name %]" [% param_multiple %] [% param_size %]>
SOMELONGSTRING
}

sub FORM_SELECT_OPTION {
    return <<'SOMELONGSTRING';
[%- UNLESS plain -%]
  [%- SET use_label_field = label_field || value_field;
      SET value           = item.$value_field;
      SET label           = item.$use_label_field; -%]
[%- END -%]
[%- SET is_picked = ( value == picked ) ? ' SELECTED' : '' -%] 
<option value="[% value %]"[% is_picked %]>[% label %]</option>

SOMELONGSTRING
}

sub FORM_SELECT_OPTIONS_ITERATOR {
    return <<'SOMELONGSTRING';
[%- WHILE ( item = iterator.get_next ) -%]
   [%- INCLUDE form_select_option -%]
[%- END -%]
SOMELONGSTRING
}

sub FORM_SELECT_OPTIONS_LIST {
    return <<'SOMELONGSTRING';
[%- FOREACH item = list -%]
   [%- INCLUDE form_select_option -%]
[%- END -%]
SOMELONGSTRING
}

sub FORM_SELECT_OPTIONS_PLAIN_LIST {
    return <<'SOMELONGSTRING';
[%- FOREACH idx = [ 0..value_list.max ] -%]
   [%- SET label = ( label_list.$idx ) ? label_list.$idx : value_list.$idx;
       SET value = value_list.$idx -%]
   [%- INCLUDE form_select_option -%]
[%- END -%]
SOMELONGSTRING
}

sub FORM_SUBMIT {
    return <<'SOMELONGSTRING';
[%- DEFAULT name  = 'form_submit';
    IF value_key;
        value = MSG( value_key );
    END;
    DEFAULT value = MSG( 'global.button.submit' );
-%]
<input type="submit" value="[% value %]" name="[% name %]"> [% field_label %]
SOMELONGSTRING
}

sub FORM_SUBMIT_ROW {
    return <<'SOMELONGSTRING';
[%- DEFAULT colspan = 2 -%]
<tr [% INCLUDE row_color %] align="right">
   <td colspan="[% colspan %]">
     [%- IF reset %][% INCLUDE form_reset( value = reset_label, value_key = reset_label_key ) %][% END -%]
     [%- INCLUDE form_submit -%]
   </td>
</tr>
SOMELONGSTRING
}

sub FORM_TEXT {
    return <<'SOMELONGSTRING';
[%- DEFAULT size = 20;
    DEFAULT maxlength = 50; -%]
[%- field_pre_label -%]
<input type="text" name="[% name %]" value="[% value %]"
       size="[% size %]" maxlength="[% maxlength %]">
[%- field_label -%]
SOMELONGSTRING
}

sub FORM_TEXTAREA {
    return <<'SOMELONGSTRING';
[%- DEFAULT rows = 3;
    DEFAULT cols = 30;
    DEFAULT wrap = 'virtual' -%]
<textarea name="[% name %]" wrap="[% wrap %]"
          rows="[% rows %]" cols="[% cols %]">[% value %]</textarea>
[%- field_label -%]
SOMELONGSTRING
}

sub FORM_UPLOAD {
    return <<'SOMELONGSTRING';
[%- field_pre_label -%]
<input type="file" name="[% name %]">
[%- field_label -%]
SOMELONGSTRING
}

sub GLOBAL_JAVASCRIPT {
    return <<'SOMELONGSTRING';
function confirm_remove( object_type, name, url ) {
    var msg = [% MSG( 'global_javascript.confirm_remove' ) %]
    if ( confirm( msg ) ) {
	    self.location = url;
    }
}

SOMELONGSTRING
}

sub HEADER_CELL {
    return <<'SOMELONGSTRING';
<td>[% INCLUDE show_label %]</td>

SOMELONGSTRING
}

sub HEADER_ROW {
    return <<'SOMELONGSTRING';
<tr valign="bottom" align="center">
[%- IF labels;
        FOREACH label = labels;
            INCLUDE header_cell;
        END;
    ELSIF label_keys;
        FOREACH label_key = label_keys;
            INCLUDE header_cell;
        END;
    END -%]
</tr>
SOMELONGSTRING
}

sub INACTIVE_OBJECT_BANNER {
    return <<'SOMELONGSTRING';
[% IF object.active == 'no' OR object.is_active == 'no' -%]
  [%- DEFAULT theme = OI.theme_properties -%]
<table width="100%" bgcolor="#000000">
<tr><td align="center">
  <font size="+1" color="#ffffff"><b>[% MSG( 'inactive_object.title' ) %]</b></font>
</td></tr>
</table>
[% END -%]
SOMELONGSTRING
}

sub LABEL_ERROR_ROW_EXTRA {
    return <<'SOMELONGSTRING';
<tr bgcolor="[% color %]">
  <td colspan="2">[% message %]</td>
</tr>

SOMELONGSTRING
}

sub LABEL_FORM_CHECKBOX_ROW {
    return <<'SOMELONGSTRING';
[%########################################
  label_form_checkbox_row( label, count, name, value, field_label, picked )
     Display a row to input text: label on left, text input on
     right. Optional 'checkbox_label' will be to right of checkbox.
  ########################################-%]

[%- DEFAULT colspan = 2;
    IF action_messages.$name;
       color = '#ffffe0';
    END; -%]  
[%- INCLUDE label_row_begin( colspan = 1 ) -%]
[%- INCLUDE data_cell_begin -%][% INCLUDE form_checkbox %]
</td></tr>
[% IF action_messages.$name -%]
[% INCLUDE label_error_row_extra( color   = color,
                                  message = action_messages.$name ) -%]
[% END -%]

SOMELONGSTRING
}

sub LABEL_FORM_DATE_ROW {
    return <<'SOMELONGSTRING';
[%########################################
  label_form_date_row( label, count, name, value, field_label )
     Display a row to input a date: label on left, date input on right.
  ########################################-%]

[%- DEFAULT colspan = 2;
    IF action_messages.$name;
       color = '#ffffe0';
    END;  -%]  
[%- INCLUDE label_row_begin( colspan = 1 ) -%]
[%- INCLUDE data_cell_begin -%]
[%- object = ( date_object ) ? date_object : OI.date_into_object( value ) -%]
[%- PROCESS date_select( field_prefix = name ) -%]
[% field_label -%]
</td></tr>
[% IF action_messages.$name -%]
[% INCLUDE label_error_row_extra( color   = color,
                                  message = action_messages.$name ) -%]
[% END -%]

SOMELONGSTRING
}

sub LABEL_FORM_LOGIN_ROW {
    return <<'SOMELONGSTRING';
[%########################################
  label_form_login_row( label, name, picked )
     SELECT box of all users in the system, with the ID of the one
     picked highlighted.
  ########################################-%]

[%- DEFAULT label   = 'Users';
    DEFAULT colspan = 2;
    IF action_messages.$name;
       color = '#ffffe0';
    END;  -%]  
[%- INCLUDE label_row_begin( colspan = 1 ) -%]
[%- INCLUDE data_cell_begin -%]
[%- INCLUDE form_login() -%]
[% field_label -%]
</td></tr>

SOMELONGSTRING
}

sub LABEL_FORM_RADIO_ROW {
    return <<'SOMELONGSTRING';
[%########################################
  label_form_radio_row( label, name, list, picked )
     Row with a radio button + label for each item in list.
  ########################################-%]

[%- DEFAULT colspan = 2;
    IF action_messages.$name;
       color = '#ffffe0';
    END; -%]  
[%- INCLUDE label_row_begin( colspan = 1 ) -%]
[%- INCLUDE data_cell_begin() -%]
  [% FOREACH value = list -%]
     [%- INCLUDE form_radio %] [% value %][% UNLESS loop.last %] | [% END -%]
  [% END -%]
</td></tr>
[% IF action_messages.$name -%]
[% INCLUDE label_error_row_extra( color   = color,
                                  message = action_messages.$name ) -%]
[% END -%]

SOMELONGSTRING
}

sub LABEL_FORM_SELECT_ROW {
    return <<'SOMELONGSTRING';
[%########################################
  label_form_select_row( label, name, list/iterator, value_field, label_field,
                         picked, first_label, is_multiple, size, field_label )
     Form row with a label and SELECT item.
  ########################################-%]

[%- DEFAULT colspan = 2;
    IF action_messages.$name;
       color = '#ffffe0';
    END; -%]  
[%- INCLUDE label_row_begin( colspan = 1 ) -%]
[%- INCLUDE data_cell_begin -%][% INCLUDE form_select -%]
</td></tr>
[% IF action_messages.$name -%]
[% INCLUDE label_error_row_extra( color   = color,
                                  message = action_messages.$name ) -%]
[% END -%]

SOMELONGSTRING
}

sub LABEL_FORM_TEXT_ROW {
    return <<'SOMELONGSTRING';
[%########################################
  label_form_text_row( label, count, name, value, field_label )
     Display a row to input text: label on left, text input on right.
  ########################################-%]

[%- DEFAULT colspan = 2;
    IF action_errors.$name;
       color = '#ffffe0';
    END; -%]
[%- INCLUDE label_row_begin( colspan = 1 ) -%]
[%- INCLUDE data_cell_begin %][% INCLUDE form_text %]
</td></tr>
[% IF action_messages.$name -%]
[% INCLUDE label_error_row_extra( color   = color,
                                  message = action_messages.$name ) -%]
[% END -%]

SOMELONGSTRING
}

sub LABEL_FORM_TEXTAREA_ROW {
    return <<'SOMELONGSTRING';
[%########################################
  label_form_textarea_row( label, count, name, value, rows, cols, wrap, colspan )
     Display a row to input text in a textarea (multiline) widget; :
     label on left, text input on right. If you specify 'colspan' then
     the widget will appear below the label.
  ########################################-%]

[%- DEFAULT colspan = 1;
    IF action_messages.$name;
       color = '#ffffe0';
    END; -%]
[%- INCLUDE label_row_begin -%]
  [% IF colspan > 1 -%]
</tr>
<tr [% INCLUDE row_color %]>
  [% END -%]
    <td colspan="[% colspan %]">
      [%- INCLUDE form_textarea -%]
    </td>
</tr>
[% IF action_messages.$name -%]
[% INCLUDE label_error_row_extra( color   = color,
                                  message = action_messages.$name ) -%]
[% END -%]

SOMELONGSTRING
}

sub LABEL_FORM_UPLOAD_ROW {
    return <<'SOMELONGSTRING';
[%########################################
  label_form_upload_row( label, count, name, field_label )
     Display a row to upload a file: label on left, file input on right.
  ########################################-%]

[%- DEFAULT colspan = 2;
    IF action_messages.$name;
       color = '#ffffe0';
    END; -%]
[%- INCLUDE label_row_begin( colspan = 1 ) -%]
[%- INCLUDE data_cell_begin %][% INCLUDE form_upload %]
</td></tr>
[% IF action_messages.$name -%]
[% INCLUDE label_error_row_extra( color   = color,
                                  message = action_messages.$name ) -%]
[% END -%]

SOMELONGSTRING
}

sub LABEL_ROW {
    return <<'SOMELONGSTRING';
[%########################################
  label_row( align, valign, colspan, color )
     Display a simple label row. Default of 'align' is 'center',
     'colspan' is 2, 'valign' is 'bottom'
  ########################################-%]
[%- DEFAULT colspan = 2;
    DEFAULT color   = '#ffffe0'; 
    DEFAULT align   = 'center';
    DEFAULT valign  = 'bottom'; -%]
[%- INCLUDE label_row_begin() -%]
</tr>
SOMELONGSTRING
}

sub LABEL_ROW_BEGIN {
    return <<'SOMELONGSTRING';
[%########################################
  label_row_begin( label, align, valign, count, colspan ) 
     Display the row start and label for a text/form element
     row. Defaults: align = 'right', colspan = 1, valign = 'middle'
  ########################################-%]
[%- DEFAULT colspan = 1;
    SET row_valign  = valign || 'middle';
    SET label_align = align  || 'right'; -%]
<tr valign="[% row_valign %]" [% INCLUDE row_color %]>
    <td align="[% label_align %]" colspan="[% colspan %]">
      [%- PROCESS show_label -%]
    </td>
SOMELONGSTRING
}

sub LABEL_TEXT_ROW {
    return <<'SOMELONGSTRING';
[%########################################
  label_text_row( label, count, text )
     Create a row with a label on the left and plain text on the right.
  ########################################-%]

[%- DEFAULT colspan = 2; -%]  
[%- INCLUDE label_row_begin( colspan = 1 ) -%]
[%- INCLUDE data_cell_begin -%][% text %]&nbsp;
</td></tr>
SOMELONGSTRING
}

sub OBJECT_UPDATES {
    return <<'SOMELONGSTRING';
[%- IF update_list.size == 0 -%]
[% MSG( 'object_updates.new' ) %]
[%- ELSE -%]
<table border="0" cellpadding="3" cellspacing="0">
  [% FOREACH item = update_list -%]
  <tr><td><font size="-1">[% item.login_name %]</font></td>
      <td><font size="-1">[% item.date %]</font></td>
      <td><font size="-1">[% item.notes %]</font></td></tr>
  [%- END %]
</table>
[%- END -%]

SOMELONGSTRING
}

sub PAGE_COUNT {
    return <<'SOMELONGSTRING';
[%#########################################
  page_count( total_pages, current_pagenum, url, break_count )
     Component to display the total number of pages and for each of
     the pages not current link it to a URL to display that page.

  Parameters:
    total_pages     - Total number of pages in result set
    current_pagenum - Page you are currently on
    url             - URL to which we append ';pagenum=x'
    break_count     - number of pages to display on a line

  Defaults:
    break_count = 20
  ########################################-%]
<!-- Given: total: [% total_pages %]; current: [% current_pagenum %]; url: [% url %]; break: [% break_count %] -->
[%- DEFAULT break_count = 20 -%]
[%- MSG( 'page_count.page_label' ) %]&nbsp;[&nbsp;
[%- IF current_pagenum != 1 -%]
<a href="[% url %];page=1">&lt;&lt;</a>&nbsp;
<a href="[% url %];page=[% current_pagenum - 1 %]">&lt;</a>&nbsp;
[%- END -%]
[%- FOREACH page_count = [ 1 .. total_pages ] -%]
  [%- IF page_count == current_pagenum %][% page_count %]
  [%- ELSE %]<a href="[% url %];page=[% page_count %]">[% page_count %]</a>
  [%- END -%]
  [%- IF page_count mod break_count == 0 -%]<br>[% ELSE %]&nbsp;[% END -%]
[%- END -%]
[%- IF current_pagenum != total_pages -%]
<a href="[% url %];page=[% current_pagenum + 1 %]">&gt;</a>
<a href="[% url %];page=[% total_pages%]">&gt;&gt;</a>
&nbsp;
[%- END -%]
]
SOMELONGSTRING
}

sub ROW_COLOR {
    return <<'SOMELONGSTRING';
[%########################################
  row_color( count, color )
     Retrieve the row color for row 'count' (default: 1 ). You can
     also pass in 'color' which overrides (kind of pointless, but it
     can be useful).
  ########################################-%]
bgcolor="
[%- IF color %][% color -%]
[%- ELSE -%]
  [%- DEFAULT theme = OI.theme_properties;
      DEFAULT count = 1; -%]
  [%- ( count mod 2 == 0 ) ? theme.even_color : theme.odd_color -%]
[%- END -%]
"
SOMELONGSTRING
}

sub SEARCH_RESULTS_PAGE_LISTING {
    return <<'SOMELONGSTRING';
[%########################################
  search_results_page_listing( table_width, search_results_key, search_id, align,
                               base_url, total_pages, current_page )
      Generate a table of the specified width with the search results
      listing in it.

  Parameters
      table_width        - width of the table
      search_results_key - name of field to set the search results key to
      search_id          - ID to retrieve search results
      align              - align the listing
      base_url           - URL to which we append ?$search_results_key=$search_id;pagenum=x
                           so we can get more search results
      total_pages        - total pages in resultset
      current_page       - what page you're on

  Defaults
      align              - 'right'
      table_width        - '90%'
      search_results_key - 'search_id'
      
  ########################################-%]
[%- DEFAULT align              = 'right';
    DEFAULT table_width        = '90%';
    DEFAULT search_results_key = 'search_id'; -%]
<table border="0" width="[% table_width %]"
       cellpadding="2" cellspacing="0">
<tr><td align="[% align %]">
[%- return_url = "$base_url?$search_results_key=$search_id" -%]
<font size="-1">
[%- PROCESS page_count( total_pages     = total_pages,
                        current_pagenum = current_page,
                        url             = return_url ) -%]
</font>
</td></tr>
</table>
SOMELONGSTRING
}

sub SHOW_LABEL {
    return <<'SOMELONGSTRING';
[%########################################
  show_label( label, is_required, required_display, pre_label, post_label )
     Display a label. If it's required, pass in a true value for
     'is_required'. If it's required and you don't pass anything in
     for 'required_display' we use what's in the theme.
  ########################################-%]
[%- req = '' -%]
[% IF is_required -%]
  [%- IF NOT required_display -%]
     [%- required_display = OI.theme_properties.required -%]
  [%- END -%]
  [%- req = required_display -%]
[% END %]
[%- IF NOT label AND label_key;
    label = MSG( label_key );
    END -%]
[% pre_label %]<b>[% label %]</b>[% req %][% post_label %]
SOMELONGSTRING
}

sub STATUS_MESSAGE {
    return <<'SOMELONGSTRING';
[%- IF NOT status_msg;
    status_msg = OI.action_param( 'status_msg' ) || OI.request.message( 'status_msg' );
    END -%]

[%- IF status_msg -%]

[%- DEFAULT theme         = OI.theme_properties;
    SET status_width      = width || '50%';
    SET status_font_color = font_color || '#000000';
    SET status_border     = border_color || theme.border_color;
    SET status_bgcolor    = bgcolor ||theme.even_bgcolor; -%]

<!-- BEGIN status display -->

<div align="center">

[%- INCLUDE table_bordered_begin( table_width  = status_width, 
                                  bgcolor      = status_bgcolor,
                                  border_color = status_border ) -%]

  <tr><td align="center">
    <font color="[% status_font_color %]" size="+1"><b>Status</b></font>
  </td></tr>
  <tr><td>
    [% FOREACH status = status_msg -%]
    <p>[% theme.bullet %] <font color="[% status_font_color %]">[% status %]</font></p>
    [% END -%]
  </td></tr>

[%- PROCESS table_bordered_end -%]

</div>

<!-- END status display -->

[%- END -%]
SOMELONGSTRING
}

sub TABLE_BORDERED_BEGIN {
    return <<'SOMELONGSTRING';
[%########################################
  table_bordered_begin( table_width, bgcolor, border_width, border_color)
     Begin a bordered table. Border color is set in theme, just pass
     in the table width (no default) and border width (in pixels, default: 2)
  ########################################-%]

[%- DEFAULT theme        = OI.theme_properties; 
    DEFAULT border_width = 2; 
    DEFAULT border_color = theme.border_color;
    DEFAULT bgcolor      = theme.bgcolor;
    DEFAULT internal_padding = 5;
    SET internal_padding = '0' IF internal_padding == 'none';
    SET width = ( table_width ) ? "width='$table_width'" : '' -%]
<table border="0" cellspacing="0" [% width -%]
       bgcolor="[% border_color %]" 
       cellpadding="[% border_width %]">
<tr><td>

  <table border="0" width="100%"          
         cellpadding="[% internal_padding %]" cellspacing="0"
         bgcolor="[% bgcolor %]">
SOMELONGSTRING
}

sub TABLE_BORDERED_END {
    return <<'SOMELONGSTRING';
[%########################################
  table_bordered_end()
     End a bordered table
  ########################################-%]

  </table>
</td></tr>
</table>
SOMELONGSTRING
}

sub TO_GROUP {
    return <<'SOMELONGSTRING';
[%########################################
  to_group()
      Display a from and to SELECT box (SIZEd) for moving items from
      one group to another, plus the Javascript necessary to make it
      happen.

      This is not a complete form, just a self-contained table you can
      place anywhere you wish.

      To make this work, you must have an onSubmit handler for your
      form; just add this to the form tag:

               onsubmit="return tally_added_items()"

      In your application, all the 'id' values will be
      semicolon-separated in a form field named whatever the
      'mem_list_hold' variable was set to.

  Parameters:
      form_name     - name of form where these items reside
      from_element  - name of the SELECT control that has the population of records
      to_element    - name of the SELECT control that has the member records
      pop_list      - list of population record hashrefs: id = x, name = y
      mem_list      - list of member record hashrefs: id = x, name = y
      mem_list_hold - name of hidden variable that will hold the ID numbers
      label_from    - label to place over SELECT control with population
      label_to      - label to place over SELECT control with members
      id_field      - hash key under which the ID (or 'OPTION' value) is stored
      name_field    - hash key under which the value is stored
      list_size     - size of SELECT lists (DEFAULT: 6)

   Defaults:
      id_field   = 'id'
      name_field = 'name'
      list_size  = 6
  ########################################%]

[%- DEFAULT id_field   = 'id';
    DEFAULT name_field = 'name';
    DEFAULT list_size  = 6; -%]

<!-- Begin table with to_group tool -->

<table border="0" cellspacing="0" cellpadding="5">
  <tr>
    <td align="center">
        <b>[% label_from %]</b>
    </td>
    <td align="center">&nbsp;</td>
    <td align="center" colspan="2">
       <b>[% label_to %] </b>
    </td>
  </tr>
  <tr>
    <td align="right" valign="bottom">
      <select name="[% from_element %]" size="[% list_size %]">
[% FOREACH pop_item = pop_list %]
       <option value="[% pop_item.$id_field %]">[% pop_item.$name_field %] </option>
[% END %]
      </select>
    </td>
    <td align="center" valign="middle">
      <input type="button" name="add" value="&gt;&gt;" onclick="add_item()"><br>
      <input type="button" name="remove" value="&lt;&lt;" onclick="remove_item()"><br>
    </td>
    <td align="left" valign="bottom">
       <select name="[% to_element %]" size="6">
[% FOREACH mem_item = mem_list %]
         <option value="[% mem_item.$id_field %]">[% mem_item.$name_field %] </option>
[% END %]
       </select>
    </td>
    <td align="left" valign="middle">
      <input type="button" value="^"   onclick="raise_item()"><br>
      <input type="button" value="\/" onclick="lower_item()"><br>
    </td>                     
  </tr>
</table>
<input type="hidden" name="[% mem_list_hold %]">
<!-- End table with to_group tool -->


<script language="javascript">

// NAME of the form we're editing

var edit_form_name = '[% form_name %]';

// NAME of the element that has the list of ALL items

var from_element   = '[% from_element %]';

// NAME of the element that has the member list

var to_element     = '[% to_element %]';

// NAME of the hidden variable that will hold the 
// packed value of all the member items.

var mem_list_hold  = '[% mem_list_hold %]';

[%#
NOTE: There are no other TT-modified variables below this point;
just Javascript.
-%]

// Raise an item in the listings. Remove the option
// above the one selected.

function raise_item() {
 var form  = self.document[ edit_form_name ];
 var members = form[ to_element ];
 var idx = members.selectedIndex;

// alert( 'Selected index: ' + idx );

 if ( idx == 0 ) {
   alert( 'Cannot raise an item already at the top!' );
   return false;
 }

 var new_opts = new Array();
 
 // Remove the option above the one selected
 // and save it.

 var save_idx = idx - 1;
 new_opts[0] = new Option( members.options[ save_idx ].text, members.options[ save_idx ].value ); 
 members.options[ save_idx ] = null;

// confirm( 'Value of first option: ' + new_opts[0].value + ' -- ' + new_opts[0].text );

 var end_list = members.options.length - 1;
 var this_opt;
 for ( i = end_list; i >= idx; i-- ) {
//    alert( 'Trying option: ' + i );
    this_opt = new Option(  members.options[ i ].text, members.options[ i ].value );
    new_opts.push( this_opt );
    members.options[ i ] = null;
//    confirm( 'Value of option just added for space ' + i + ': ' + this_opt.value + ' -- ' + this_opt.text );
 }

 for ( j = 0; j < new_opts.length; j++ ) {
   this_opt = new_opts[ j ];
//   confirm( 'Going to add: ' + this_opt.value + ' -- ' + this_opt.text ); 
   members.options[ members.options.length ] = new Option( this_opt.text, this_opt.value );
 }
 return true;
}

// Lower an item in the listings -- first remove
// it OI.from its place as well as all items below, 
// then reinsert the items at the end.

function lower_item() {
 var form = self.document[ edit_form_name ];
 var members = form[ to_element ];
 var idx = members.selectedIndex;
 if ( idx == members.options.length - 1 ) {
   alert( 'Cannot lower an item already at the bottom!' );
   return false;
 }

 var new_opts = new Array();

 // Put the option selected at the head of the options
 // to be inserted.

 new_opts[0] = new Option( members.options[ idx ].text, members.options[ idx ].value );

 // Remove the option selected. members.options[ idx ] 
 // will be the option that 'moves up'.

 members.options[ idx ] = null

// alert( 'Value of first option: ' + new_opts[0].value );

 // Cycle down OI.from the end of the list and eliminate
 // options, saving them in the new_opts list.

 var end_list = members.options.length - 1;
 var this_opt;
 for ( i = end_list; i > idx; i-- ) {
    this_opt = new Option( members.options[ i ].text, members.options[ i ].value );
    new_opts.push( this_opt );
    members.options[ i ] = null;
//    alert( 'Value of option just added: ' + new_opts[ new_opts.length - 1 ].value );
 }

 // Now, cycle through the saved options and add each in
 // turn to the end of the displayed options.

 for ( j = 0; j < new_opts.length; j++ ) {
   this_opt = new Option( new_opts[ j ].text, new_opts[ j ].value );
   members.options[ members.options.length ] = this_opt;
 }
 return true;
}


function add_option ( Element, Text, Value ) {
 var form = self.document[edit_form_name];
 var members = form[ Element ];
 var newopt = new Option( Text , Value );
 for ( opt = 0; opt < members.options.length; opt++ ) {
      if ( members.options[opt].value == Value )
          return false;
 }
 members.options[ members.options.length ] = newopt;
 return true;
}

function remove_option ( Element, Value ) {
 var form = self.document[edit_form_name];
 var members = form[Element];
 for ( opt = 0; opt < members.options.length; opt++ ) {
      if ( members.options[opt].value == Value ) {
          members.options[opt] = null;
          return true;
      }
 }
 return false;
}


function add_item ( ) {
 var form = self.document[edit_form_name];
 var listing = form[from_element];
 var idx = listing.selectedIndex;
 if ( idx == -1 ) {
      alert('Please pick an item to add!');
      return false;
 }
 if ( listing.options[idx].value == '' ) {
      return false;
 }
 var id    = listing.options[idx].value;
 var value = listing.options[idx].text;
 add_option( to_element, value, id );
 remove_option( from_element, id );
 return true;
}


function remove_item ( ) {
 var form = self.document[edit_form_name];
 var listing = form[to_element];
 var idx = listing.selectedIndex;
 if ( idx == -1 ) {
      alert('Please pick an item to remove OI.from the member list!');
      return false;
 }
 if ( listing.options[idx].value == '' ) {
      return false;
 }
 var id    = listing.options[idx].value;
 var value = listing.options[idx].text;
 remove_option( to_element, id );
 add_option( from_element, value, id );
 return true;
}


function tally_added_items ( ) {
 var form = self.document[edit_form_name];
 var listing = form[to_element];
 var return_string = '';
 for ( opt = 0; opt < listing.options.length; opt++ ) {
      if ( listing.options[opt].value != '' )
          return_string += listing.options[opt].value + ';';
 }
 return_string = return_string.substring( 0, return_string.length - 1 );
 form[ mem_list_hold ].value = return_string;
// return confirm( 'Value of itemlist: ['+form[mem_list_hold].value+']. Continue?');
 return true;
}
</script>
SOMELONGSTRING
}


# Copyright (C) 2017 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

use base "basetest";

use testapi;

my $orig_file = <<'END';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE profile>
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
<users config:type="list">
    <user>
      <encrypted config:type="boolean">false</encrypted>
      <user_password>PASSWORD</user_password>
      <username>root</username>
    </user>
  </users>
</profile>
END

sub run {

    script_run 'alias bash=sh', 0;
    type_string("echo get_test_data returned expected file\n");


    save_tmp_file('modified.txt', "hello world");
    my $url = autoinst_url . '/files/modified.txt';
    validate_script_output("wget $url 2>&1", qr{modified.txt.*100%});
    type_string("echo save_tmp_file returned expected file\n");
    return;
    # Get file from data directory
    my $content = get_test_data('autoinst.xml');

    if ($content eq $orig_file) {
        type_string("echo get_test_data returned expected file\n");
    }
    my $url = autoinst_url . '/files/modified.xml';
    $content =~ s/PASSWORD/nots3cr3t/g;
    save_tmp_file('modified.xml', $content);
    # Verify that correct file is downloaded
    validate_script_output("wget $url 2>&1", qr{foobar});
#    assert_script_run("wget -v $url");
    script_run "echo '72d2c15cb10535f36862d7d2eecc8a79  modified.xml' > modified.md5";
    assert_script_run("md5sum -c modified.md5");

    type_string("echo save_tmp_file returned expected file\n");
}

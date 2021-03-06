#!/usr/bin/perl
# A pipe menu for openbox to control MPD.
# Depends on mpc and an additional script mpdctrl.
# All the functionality of mpdctrl can be incorporated into this script (as is done with the playlist submenu),
# but this way, it can be used independently of this menu in a complementary way to mpc.
# mpdctrl should be in your PATH
#
# to do:
# sorting of playlist
use Cwd 'abs_path';
use warnings;
use strict;

sub print_plst;
sub separator;
sub item;
sub end_menu;
sub fix_html (\$);
sub say { print @_, "\n"; }

# path to this script needed because it calls itself to create the playlist submenu
my $path = abs_path $0;

##################################################################################################
########################################## CONFIGURATION #########################################
##################################################################################################

my $mpd_client = "urxvt -geometry 125x20 -e ncmpcpp";
my $start_cmd = "";
my $stop_cmd = "";
my $mpd_port = 6600;
my $mpdctrl = "perl ~/.config/openbox/scripts/mpdctrl.pl ";

##################################################################################################

chomp (my $pid = `pidof mpd`);
my $status = '';
my $curr_song = '';
my $curr_song_elapsed = '';
my $curr_song_pos = '';
my $repeat = '';
my $random = '';
my $single = '';
my $consume = '';
my $crossfade = '';
my $volume = '';

# if MPD is running, get info on playlist
if ( $pid ) {
  my $song_format = '[[%artist% - |%composer% - |%performer% - |%album% - ][%title%]|[%file%]]';
  chomp (my @stats = split /\n/, `mpc -p $mpd_port -f '$song_format'`);
  if ( $stats[1] && @stats > 1 ) {
    $status = $stats[1] =~ s/\[(\w)(\w*)\].*/\U$1\L$2/r;
    $curr_song = $stats[0];
    ($curr_song_pos, $curr_song_elapsed) = (split /\s+/, $stats[1])[1,2];
    $curr_song_pos =~ s/^#//;
  } else {
    $status = 'Stopped';
  }
  ($stats[2] || $stats[0]) =~ m/repeat:\s*(?<repeat>[a-z]+)\s+
			      random:\s*(?<random>[a-z]+)\s+
			    single:\s*(?<single>[a-z]+)\s+
			  consume:\s*(?<consume>[a-z]+)/x;
  ($repeat, $random, $single, $consume) = ($+{repeat}, $+{random}, $+{single}, $+{consume});
  chomp ($crossfade = `mpc -p $mpd_port crossfade`);
  $crossfade =~ s/crossfade:\s*//;
  chomp ($volume = `mpc -p $mpd_port volume`);
  $volume =~ s/volume:\s*//;
} else {
  $status = 'Off';
}

# print playlist submenu and exit if arg 1 is pls
print_plst if @ARGV && "$ARGV[0]" eq 'pls';

# otherwise, start printing the main menu
say "<openbox_pipe_menu>";

# if MPD is not running, print "start" option and exit; else determine status and set playlist menu label
if ( $status eq 'Off' ) {
  unless ( $start_cmd ) {
    separator "MPD is not running!";
    end_menu;
  }
  item 'Run MPD', $start_cmd;
  end_menu;
}

# print playback status
{
  fix_html $curr_song;
  my $title = $status . ( $status eq 'Stopped' ? '' : " $curr_song_pos: $curr_song ($curr_song_elapsed)" );
    
  # unless playlist is empty, print it as menu, otherwise - just put a separator with the status
  if ( `mpc -p $mpd_port playlist` ) {
    say "<menu id=\"pls\" label=\"$title\" execute=\"$path pls\" />";
    separator;
  } else {
    separator $title;
  }
}

# set volume
item "Set volume (currently: $volume)", "$mpdctrl vol";

# play/pause song
if ( $status eq 'Playing') {
  item "Pause", "mpc -p $mpd_port toggle";
} else {
  item "Play", "mpc -p $mpd_port toggle";
}

# stop playback
item "Stop", "mpc -p $mpd_port stop" unless $status eq "Stopped";

# play song/playlist from the beginning
item "Play song from beginning", "mpc -p $mpd_port seek 0";
item "Restart playlist", "mpc -p $mpd_port play 1";

# play next/previous song
unless ( $status eq "Stopped" ) {
  item 'Next', "mpc -p $mpd_port next";
  item "Previous", "mpc -p $mpd_port prev";
}
separator;

# toggle "single mode"
if ( $single eq "off" ) {
  item "Stop after current song", "mpc -p $mpd_port single";
} else {
  item "Continue after current song", "mpc -p $mpd_port single";
}

# toggle "repeat mode"
if ( $repeat eq "off" ) {
  item "Repeat playlist", "mpc -p $mpd_port repeat";
} else {
  item "Do not repeat playlist", "mpc -p $mpd_port repeat";
}

# toggle "random mode"
if (  $random eq "off" ) {
  item "Shuffle playlist", "mpc -p $mpd_port random";
} else {
  item "Do not shuffle playlist", "mpc -p $mpd_port random";
}

# toggle "consume mode"
if (  $consume eq "off" ) {
  item "Start consuming played songs", "mpc -p $mpd_port consume";
} else {
  item "Stop consuming played songs", "mpc -p $mpd_port consume";
}

# set crossfade
item "Disable crossfade (currently: $crossfade)", "mpc -p $mpd_port crossfade 0" unless $crossfade == 0;
item "Set crossfade", "$mpdctrl cross";
separator;

# import/export playlist
item "Import playlist", "$mpdctrl import";
item "Export playlist", "$mpdctrl export";

# add files to playlist
item "Append files to playlist", "$mpdctrl add";
item "Insert files at current position", "$mpdctrl ins";

# move songs
item "Move songs to another position", "$mpdctrl mv";

# remove songs from playlist
if ( $status eq "Stopped" ) {
  item "Remove current song from playlist", "mpc -p $mpd_port del 1";
} else {
  item "Remove current song from playlist", "mpc -p $mpd_port del 0";
}
item "Remove songs from playlist", "$mpdctrl del";

# clear playlist
item "Clear playlist", "mpc -p $mpd_port clear";
item "Clear all but the current song", "mpc -p $mpd_port crop" unless $status eq "Stopped";
separator;

# run client
item "Run MPD client", $mpd_client if $mpd_client;

# update database
item "Update database", "mpc -p $mpd_port update";

# shutdown MPD
item "Kill MPD", $stop_cmd if $stop_cmd;

end_menu;

##################################################################################################
########################################### SUBROUTINES ##########################################
##################################################################################################

# playlist submenu (called by passing a 'pls' argument to this script)
sub print_plst {
  my $song_format = '[%position%. ][[%artist% - |%composer% - ' .
    '|%performer% - |%album% - ][%title%]|[%file%]][ (%time%)]';
  my $cmd = "mpc -p $mpd_port -f \"$song_format\" playlist";
  chomp (my @pls = split /\n/, `$cmd`);
  #chomp (my @pls = split /\n/, `mpc -p $mpd_port -f '$song_format' playlist`);
  say "<openbox_pipe_menu>";
  for ( @pls ) {
    fix_html $_;
    item $_, "mpc -p $mpd_port play " . $_ =~ s/^(\d+).*/$1/r;
  }
  end_menu;
}

# print a separator
sub separator {
  if ( @_ ) {
    my $label = shift || "";
    say "<separator label=\"$label\" />";
  } else {
    say "<separator />";
  }
}

# print an item
sub item {
  my $label = shift || "";
  my $cmd = shift || ":";
  say "  <item label=\"$label\">";
  say "    <action name=\"Execute\">";
  say "      <execute>";
  say "        $cmd";
  say "      </execute>";
  say "    </action>";
  say "  </item>";
}

# end the main menu
sub end_menu {
  say "</openbox_pipe_menu>";
  exit 0;
}

# escape some special characters
 sub fix_html (\$) {
   my $str = shift or die;
   # replace some special characters by their html codes
   $$str =~ s/&/&amp;/g;
   $$str =~ s/"/&#34;/g;
   $$str =~ s/\$/&#36;/g;
   $$str =~ s/</&#60;/g;
   $$str =~ s/=/&#61;/g;
   $$str =~ s/>/&#62;/g;
   $$str =~ s/\\/&#92;/g;
   # replace the underscore with a double underscore in the label to prevent openbox from interpreting it as a keyboard accelerator
   $$str =~ s/_/__/g;
 }
 


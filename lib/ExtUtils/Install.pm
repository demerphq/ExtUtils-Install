package ExtUtils::Install;

use 5.00503;
use strict;

use vars qw(@ISA @EXPORT $VERSION $MUST_REBOOT %Config);
$VERSION = '1.37'; # experimental release

use Exporter;
use Carp ();
use Config qw(%Config);

@ISA = ('Exporter');
@EXPORT = ('install','uninstall','pm_to_blib', 'install_default');

my $Is_VMS     = $^O eq 'VMS';
my $Is_MacPerl = $^O eq 'MacOS';
my $Is_Win32   = $^O eq 'MSWin32';
my $Is_cygwin  = $^O eq 'cygwin';
my $CanMoveAtBoot = ($Is_Win32 || $Is_cygwin);

# *note* CanMoveAtBoot is only incidentally the same condition as below
# this needs not hold true in the future.
my $Has_Win32API_File = ($Is_Win32 || $Is_cygwin)
    ? (eval {require Win32API::File; 1} || 0)
    : 0;


my $Inc_uninstall_warn_handler;

# install relative to here

my $INSTALL_ROOT = $ENV{PERL_INSTALL_ROOT};

use File::Spec;
my $Curdir = File::Spec->curdir;
my $Updir  = File::Spec->updir;


=head1 NAME

ExtUtils::Install - install files from here to there

=head1 SYNOPSIS

  use ExtUtils::Install;

  install({ 'blib/lib' => 'some/install/dir' } );

  uninstall($packlist);

  pm_to_blib({ 'lib/Foo/Bar.pm' => 'blib/lib/Foo/Bar.pm' });


=head1 DESCRIPTION

Handles the installing and uninstalling of perl modules, scripts, man
pages, etc...

Both install() and uninstall() are specific to the way
ExtUtils::MakeMaker handles the installation and deinstallation of
perl modules. They are not designed as general purpose tools.

On some operating systems such as Win32 installation may not be possible
until after a reboot has occured. This can have varying consequences:
removing an old DLL does not impact programs using the new one, but if
a new DLL cannot be installed properly until reboot then anything
depending on it must wait. The package variable

  $ExtUtils::Install::MUST_REBOOT

is used to store this status.

If this variable is true then such an operation has occured and
anything depending on this module cannot proceed until a reboot
has occured.

If this value is defined but false then such an operation has
ocurred, but should not impact later operations.

=cut


sub _chmod($$;$) {
    my ( $mode, $item, $verbose )=@_;
    $verbose ||= 0;
    if (chmod $mode, $item) {
        print "chmod($mode, $item)\n" if $verbose > 1;
    } else {
        my $err="$!";
        warn "Failed chmod($mode, $item): $err\n"
            if -e $item;
    }
}

# Schedules a file to be moved/renamed/deleted at next boot.
# $file should be a filespec of an existing file
# $target should be a ref to an array if the file is to be deleted
# otherwise it should be a filespec for a rename. If the file is existing
# it will be replaced.
# returns 1 on success, undef if the operation is meaningless on the
# current OS, and dies otherwise.
# Sets $MUST_REBOOT to 0 to indicate a deletion operation has occured
# and sets it to 1 to indicate that a move operation has been requested.
#

sub _move_file_at_boot {
    my ( $file, $target )= @_;
    Carp::confess("Panic: Can't _move_file_at_boot on this platform!")
         unless $CanMoveAtBoot;

    my $descr= ref $target
                ? "'$file' for deletion"
                : "'$file' for installation as '$target'";

    if ( ! $Has_Win32API_File ) {
        die '!' x 72, "\n",
            "ERROR: Cannot schedule $descr at reboot.",
            "Try installing Win32API::File to allow operations on locked files\n",
            "to be scheduled during reboot. Or try to perform the operation by hand yourself.\n",
            '!' x 72, "\n";
    }
    my $opts= Win32API::File::MOVEFILE_DELAY_UNTIL_REBOOT();
    $opts= $opts | Win32API::File::MOVEFILE_REPLACE_EXISTING()
        unless ref $target;

    _chmod( 0666, $file );
    _chmod( 0666, $target ) unless ref $target;

    if (Win32API::File::MoveFileEx( $file, $target, $opts )) {
        $MUST_REBOOT ||= ref $target ? 0 : 1;
        return 1;
    } else {
        die '!' x 72, "\n",
            "ERROR: MoveFileEx $descr at reboot failed: $^E\n",
            '!' x 72, "\n";
    }
}

#
# _unlink_or_rename
#
# Tries to unlink $file, if unlink isnt possible tries to rename the
# file to a temporary name and schedule the file for deletion later.
# If the rename fails and $installing is true then schedules that
# the tempfile be renamed to the correct name at boot.
# Returns the filename to use for installation or the filename that
# was deleted. Dies on failure.
# Note that when $installing is true the caller is expected to install
# the file under the returned filename.
#
#

sub _unlink_or_rename {
    my ( $file, $tryhard, $installing )= @_;

    _chmod( 0666, $file );
    unlink $file
        and return $file;
    my $error="$!";

    Carp::croak('!' x 72, "\n",
            "ERROR: Cannot unlink '$file': $!\n",
            '!' x 72, "\n")
          unless $CanMoveAtBoot && $tryhard;

    my $tmp= "AAA";
    ++$tmp while -e "$file.$tmp";
    $tmp= "$file.$tmp";

    warn "WARNING: Unable to unlink '$file': $error\n",
         "Going to try to rename it to '$tmp'.\n";

    if ( rename $file, $tmp ) {
        warn "Rename succesful.\n",
             "WARNING: Scheduling '$tmp' for deletion at reboot.\n";
        _move_file_at_boot( $tmp, [] );
	return $file;
    } elsif ( $installing ) {
        warn "WARNING: Rename failed: $!\n",
             "WARNING: Scheduling '$tmp' for installation as '$file' at reboot.\n";
        _move_file_at_boot( $tmp, $file );
        return $tmp;
    } else {
        Carp::croak('!' x 72, "\n",
            "ERROR: Cannot unlink '$file': $error\n",
            "ERROR: Cannot rename '$file': $!\n",
            '!' x 72, "\n");
    }

}

=head2 Functions

=over 4

=item B<install>

    install(\%from_to);
    install(\%from_to, $verbose, $dont_execute, $uninstall_shadows);

Copies each directory tree of %from_to to its corresponding value
preserving timestamps and permissions.

There are two keys with a special meaning in the hash: "read" and
"write".  These contain packlist files.  After the copying is done,
install() will write the list of target files to $from_to{write}. If
$from_to{read} is given the contents of this file will be merged into
the written file. The read and the written file may be identical, but
on AFS it is quite likely that people are installing to a different
directory than the one where the files later appear.

If $verbose is true, will print out each file removed.  Default is
false.  This is "make install VERBINST=1"

If $dont_execute is true it will only print what it was going to do
without actually doing it.  Default is false.

If $uninstall_shadows is true any differing versions throughout @INC
will be uninstalled.  This is "make install UNINST=1"

=cut



sub install {
    my($from_to,$verbose,$nonono,$inc_uninstall) = @_;
    $verbose ||= 0;
    $nonono  ||= 0;

    use Cwd qw(cwd);
    use ExtUtils::Packlist;
    use File::Basename qw(dirname);
    use File::Copy qw(copy);
    use File::Find qw(find);
    use File::Path qw(mkpath);
    use File::Compare qw(compare);

    my(%from_to) = %$from_to;
    my(%pack, $dir, $warn_permissions);
    my($packlist) = ExtUtils::Packlist->new();
    # -w doesn't work reliably on FAT dirs
    $warn_permissions++ if $Is_Win32;
    local(*DIR);
    for (qw/read write/) {
	$pack{$_}=$from_to{$_};
	delete $from_to{$_};
    }
    my($source_dir_or_file);
    foreach $source_dir_or_file (sort keys %from_to) {
	#Check if there are files, and if yes, look if the corresponding
	#target directory is writable for us
	opendir DIR, $source_dir_or_file or next;
	for (readdir DIR) {
	    next if $_ eq $Curdir || $_ eq $Updir || $_ eq ".exists";
            my $targetdir = install_rooted_dir($from_to{$source_dir_or_file});
            mkpath($targetdir) unless $nonono;
	    if (!$nonono && !-w $targetdir) {
		warn "Warning: You do not have permissions to " .
		    "install into $from_to{$source_dir_or_file}"
		    unless $warn_permissions++;
	    }
	}
	closedir DIR;
    }
    my $tmpfile = install_rooted_file($pack{"read"});
    $packlist->read($tmpfile) if (-f $tmpfile);
    my $cwd = cwd();

    MOD_INSTALL: foreach my $source (sort keys %from_to) {
	#copy the tree to the target directory without altering
	#timestamp and permission and remember for the .packlist
	#file. The packlist file contains the absolute paths of the
	#install locations. AFS users may call this a bug. We'll have
	#to reconsider how to add the means to satisfy AFS users also.

	#October 1997: we want to install .pm files into archlib if
	#there are any files in arch. So we depend on having ./blib/arch
	#hardcoded here.

	my $targetroot = install_rooted_dir($from_to{$source});

        my $blib_lib  = File::Spec->catdir('blib', 'lib');
        my $blib_arch = File::Spec->catdir('blib', 'arch');
	if ($source eq $blib_lib and
	    exists $from_to{$blib_arch} and
	    directory_not_empty($blib_arch)) {
	    $targetroot = install_rooted_dir($from_to{$blib_arch});
            print "Files found in $blib_arch: installing files in $blib_lib into architecture dependent library tree\n";
	}

        chdir $source or next;

	find(sub {
	    my ($mode,$size,$atime,$mtime) = (stat)[2,7,8,9];
	    return unless -f _;

            my $origfile = $_;
	    return if $origfile eq ".exists";
	    my $targetdir  = File::Spec->catdir($targetroot, $File::Find::dir);
	    my $targetfile = File::Spec->catfile($targetdir, $origfile);
            my $sourcedir  = File::Spec->catdir($source, $File::Find::dir);
            my $sourcefile = File::Spec->catfile($sourcedir, $origfile);

            my $save_cwd = cwd;
            chdir $cwd;  # in case the target is relative
                         # 5.5.3's File::Find missing no_chdir option.

	    my $diff = 0;
	    if ( -f $targetfile && -s _ == $size) {
		# We have a good chance, we can skip this one
		$diff = compare($sourcefile, $targetfile);
	    } else {
		$diff++;
	    }
            print "$sourcefile differs\n" if $diff && $verbose>1;
            my $realtarget= $targetfile;
	    if ($diff) {
	        if (-f $targetfile) {
	            print "_unlink_or_rename($targetfile)\n" if $verbose>1;
		    $targetfile= _unlink_or_rename( $targetfile, 'tryhard', 'install' )
		        unless $nonono;
		} else {
		    mkpath($targetdir,0,0755) unless $nonono;
		    print "mkpath($targetdir,0,0755)\n" if $verbose>1;
		}
		copy($sourcefile, $targetfile) unless $nonono;
		print "Installing $targetfile\n";
		utime($atime,$mtime + $Is_VMS,$targetfile) unless $nonono>1;
		print "utime($atime,$mtime,$targetfile)\n" if $verbose>1;
                $mode = 0444 | ( $mode & 0111 ? 0111 : 0 );
                _chmod( $mode, $targetfile, $verbose );
	    } else {
		print "Skipping $targetfile (unchanged)\n" if $verbose;
	    }

	    if ( defined $inc_uninstall ) {
		inc_uninstall($sourcefile,$File::Find::dir,$verbose,
                              $inc_uninstall ? 0 : 1,
                              $realtarget ne $targetfile ? $realtarget : "");
	    }

	    # Record the full pathname.
	    $packlist->{$targetfile}++;

            # File::Find can get confused if you chdir in here.
            chdir $save_cwd;

        # File::Find seems to always be Unixy except on MacPerl :(
	}, $Is_MacPerl ? $Curdir : '.' );
	chdir($cwd) or Carp::croak("Couldn't chdir to $cwd: $!");
    }

    if ($pack{'write'}) {
	$dir = install_rooted_dir(dirname($pack{'write'}));
	mkpath($dir,0,0755) unless $nonono;
	print "Writing $pack{'write'}\n";
	$packlist->write(install_rooted_file($pack{'write'})) unless $nonono;
    }

    _do_cleanup($verbose);
}

sub _do_cleanup {
    my ($verbose) = @_;
    if ($MUST_REBOOT) {
        die
            '!' x 72, "\n",
            "Operation not completed: ",
            "Please reboot to complete the Installation.\n",
            '!' x 72, "\n",
        ;
    } elsif (defined $MUST_REBOOT & $verbose) {
        warn "Installation will be completed at the next reboot.\n",
             "However it is not necessary to reboot immediately.\n";
    }
}

sub install_rooted_file {
    if (defined $INSTALL_ROOT) {
	File::Spec->catfile($INSTALL_ROOT, $_[0]);
    } else {
	$_[0];
    }
}


sub install_rooted_dir {
    if (defined $INSTALL_ROOT) {
	File::Spec->catdir($INSTALL_ROOT, $_[0]);
    } else {
	$_[0];
    }
}


# if tryhard is true then we will use whatever devious tricks we can
# to delete the file. Currently this only applies to Win32 in that it
# will try to use Win32API::File to schedule a delete at reboot.
sub forceunlink {
    my ( $file, $tryhard )= @_;
    _unlink_or_rename( $file, $tryhard );
}


sub directory_not_empty ($) {
  my($dir) = @_;
  my $files = 0;
  find(sub {
	   return if $_ eq ".exists";
	   if (-f) {
	     $File::Find::prune++;
	     $files = 1;
	   }
       }, $dir);
  return $files;
}


=item B<install_default> I<DISCOURAGED>

    install_default();
    install_default($fullext);

Calls install() with arguments to copy a module from blib/ to the
default site installation location.

$fullext is the name of the module converted to a directory
(ie. Foo::Bar would be Foo/Bar).  If $fullext is not specified, it
will attempt to read it from @ARGV.

This is primarily useful for install scripts.

B<NOTE> This function is not really useful because of the hard-coded
install location with no way to control site vs core vs vendor
directories and the strange way in which the module name is given.
Consider its use discouraged.

=cut

sub install_default {
  @_ < 2 or die "install_default should be called with 0 or 1 argument";
  my $FULLEXT = @_ ? shift : $ARGV[0];
  defined $FULLEXT or die "Do not know to where to write install log";
  my $INST_LIB = File::Spec->catdir($Curdir,"blib","lib");
  my $INST_ARCHLIB = File::Spec->catdir($Curdir,"blib","arch");
  my $INST_BIN = File::Spec->catdir($Curdir,'blib','bin');
  my $INST_SCRIPT = File::Spec->catdir($Curdir,'blib','script');
  my $INST_MAN1DIR = File::Spec->catdir($Curdir,'blib','man1');
  my $INST_MAN3DIR = File::Spec->catdir($Curdir,'blib','man3');
  install({
	   read => "$Config{sitearchexp}/auto/$FULLEXT/.packlist",
	   write => "$Config{installsitearch}/auto/$FULLEXT/.packlist",
	   $INST_LIB => (directory_not_empty($INST_ARCHLIB)) ?
			 $Config{installsitearch} :
			 $Config{installsitelib},
	   $INST_ARCHLIB => $Config{installsitearch},
	   $INST_BIN => $Config{installbin} ,
	   $INST_SCRIPT => $Config{installscript},
	   $INST_MAN1DIR => $Config{installman1dir},
	   $INST_MAN3DIR => $Config{installman3dir},
	  },1,0,0);
}


=item B<uninstall>

    uninstall($packlist_file);
    uninstall($packlist_file, $verbose, $dont_execute);

Removes the files listed in a $packlist_file.

If $verbose is true, will print out each file removed.  Default is
false.

If $dont_execute is true it will only print what it was going to do
without actually doing it.  Default is false.

=cut

sub uninstall {
    use ExtUtils::Packlist;
    my($fil,$verbose,$nonono) = @_;
    $verbose ||= 0;
    $nonono  ||= 0;

    die "no packlist file found: $fil" unless -f $fil;
    # my $my_req = $self->catfile(qw(auto ExtUtils Install forceunlink.al));
    # require $my_req; # Hairy, but for the first
    my ($packlist) = ExtUtils::Packlist->new($fil);
    foreach (sort(keys(%$packlist))) {
	chomp;
	print "unlink $_\n" if $verbose;
	forceunlink($_,'tryhard') unless $nonono;
    }
    print "unlink $fil\n" if $verbose;
    forceunlink($fil, 'tryhard') unless $nonono;
    _do_cleanup($verbose);
}

sub inc_uninstall {
    my($filepath,$libdir,$verbose,$nonono,$ignore) = @_;
    my($dir);
    $ignore||="";
    my $file = (File::Spec->splitpath($filepath))[2];
    my %seen_dir = ();

    my @PERL_ENV_LIB = split $Config{path_sep}, defined $ENV{'PERL5LIB'}
      ? $ENV{'PERL5LIB'} : $ENV{'PERLLIB'} || '';

    foreach $dir (@INC, @PERL_ENV_LIB, @Config{qw(archlibexp
						  privlibexp
						  sitearchexp
						  sitelibexp)}) {
	my $canonpath = File::Spec->canonpath($dir);
	next if $canonpath eq $Curdir;
	next if $seen_dir{$canonpath}++;
	my $targetfile = File::Spec->catfile($canonpath,$libdir,$file);
	next unless -f $targetfile;

	# The reason why we compare file's contents is, that we cannot
	# know, which is the file we just installed (AFS). So we leave
	# an identical file in place
	my $diff = 0;
	if ( -f $targetfile && -s _ == -s $filepath) {
	    # We have a good chance, we can skip this one
	    $diff = compare($filepath,$targetfile);
	} else {
	    $diff++;
	}
        print "#$file and $targetfile differ\n" if $diff && $verbose > 1;

	next if !$diff or $targetfile eq $ignore;
	if ($nonono) {
	    if ($verbose) {
		$Inc_uninstall_warn_handler ||= ExtUtils::Install::Warn->new();
		$libdir =~ s|^\./||s ; # That's just cosmetics, no need to port. It looks prettier.
		$Inc_uninstall_warn_handler->add(
                                     File::Spec->catfile($libdir, $file),
                                     $targetfile
                                    );
	    }
	    # if not verbose, we just say nothing
	} else {
	    print "Unlinking $targetfile (shadowing?)\n";
	    forceunlink($targetfile,'tryhard');
	}
    }
}

sub run_filter {
    my ($cmd, $src, $dest) = @_;
    local(*CMD, *SRC);
    open(CMD, "|$cmd >$dest") || die "Cannot fork: $!";
    open(SRC, $src)           || die "Cannot open $src: $!";
    my $buf;
    my $sz = 1024;
    while (my $len = sysread(SRC, $buf, $sz)) {
	syswrite(CMD, $buf, $len);
    }
    close SRC;
    close CMD or die "Filter command '$cmd' failed for $src";
}


=item B<pm_to_blib>

    pm_to_blib(\%from_to, $autosplit_dir);
    pm_to_blib(\%from_to, $autosplit_dir, $filter_cmd);

Copies each key of %from_to to its corresponding value efficiently.
Filenames with the extension .pm are autosplit into the $autosplit_dir.
Any destination directories are created.

$filter_cmd is an optional shell command to run each .pm file through
prior to splitting and copying.  Input is the contents of the module,
output the new module contents.

You can have an environment variable PERL_INSTALL_ROOT set which will
be prepended as a directory to each installed file (and directory).

=cut

sub pm_to_blib {
    my($fromto,$autodir,$pm_filter) = @_;

    use File::Basename qw(dirname);
    use File::Copy qw(copy);
    use File::Path qw(mkpath);
    use File::Compare qw(compare);
    use AutoSplit;

    mkpath($autodir,0,0755);
    while(my($from, $to) = each %$fromto) {
	if( -f $to && -s $from == -s $to && -M $to < -M $from ) {
            print "Skip $to (unchanged)\n";
            next;
        }

	# When a pm_filter is defined, we need to pre-process the source first
	# to determine whether it has changed or not.  Therefore, only perform
	# the comparison check when there's no filter to be ran.
	#    -- RAM, 03/01/2001

	my $need_filtering = defined $pm_filter && length $pm_filter &&
                             $from =~ /\.pm$/;

	if (!$need_filtering && 0 == compare($from,$to)) {
	    print "Skip $to (unchanged)\n";
	    next;
	}
	if (-f $to){
	    # we wont try hard here. its too likely to mess things up.
	    forceunlink($to);
	} else {
	    mkpath(dirname($to),0,0755);
	}
	if ($need_filtering) {
	    run_filter($pm_filter, $from, $to);
	    print "$pm_filter <$from >$to\n";
	} else {
	    copy($from,$to);
	    print "cp $from $to\n";
	}
	my($mode,$atime,$mtime) = (stat $from)[2,8,9];
	utime($atime,$mtime+$Is_VMS,$to);
	_chmod(0444 | ( $mode & 0111 ? 0111 : 0 ),$to);
	next unless $from =~ /\.pm$/;
	_autosplit($to,$autodir);
    }
}


=begin _private

=item _autosplit

From 1.0307 back, AutoSplit will sometimes leave an open filehandle to
the file being split.  This causes problems on systems with mandatory
locking (ie. Windows).  So we wrap it and close the filehandle.

=end _private

=cut

sub _autosplit {
    my $retval = autosplit(@_);
    close *AutoSplit::IN if defined *AutoSplit::IN{IO};

    return $retval;
}


package ExtUtils::Install::Warn;

sub new { bless {}, shift }

sub add {
    my($self,$file,$targetfile) = @_;
    push @{$self->{$file}}, $targetfile;
}

sub DESTROY {
    unless(defined $INSTALL_ROOT) {
        my $self = shift;
        my($file,$i,$plural);
        foreach $file (sort keys %$self) {
            $plural = @{$self->{$file}} > 1 ? "s" : "";
            print "## Differing version$plural of $file found. You might like to\n";
            for (0..$#{$self->{$file}}) {
                print "rm ", $self->{$file}[$_], "\n";
                $i++;
            }
        }
        $plural = $i>1 ? "all those files" : "this file";
        my $inst = (_invokant() eq 'ExtUtils::MakeMaker')
                 ? ( $Config::Config{make} || 'make' ).' install UNINST=1'
                 : './Build install uninst=1';
        print "## Running '$inst' will unlink $plural for you.\n";
    }
}

sub _invokant {
    my @stack;
    my $frame = 0;
    while (my $file = (caller($frame++))[1]) {
        push @stack, (File::Spec->splitpath($file))[2];
    }

    my $builder;
    my $top = pop @stack;
    if ($top =~ /^Build/i || exists($INC{'Module/Build.pm'})) {
        $builder = 'Module::Build';
    } else {
        $builder = 'ExtUtils::MakeMaker';
    }
    return $builder;
}


=back

=head1 ENVIRONMENT

=over 4

=item B<PERL_INSTALL_ROOT>

Will be prepended to each install path.

=back

=head1 AUTHOR

Original author lost in the mists of time.  Probably the same as Makemaker.

This experimental release is maintained by demerphq C<yves@cpan.org>

Please direct any issues to the above email, the following concerns the
production release only:

Production release currently maintained by Michael G Schwern C<schwern@pobox.com>

Send patches and ideas to C<makemaker@perl.org>.

Send bug reports via http://rt.cpan.org/.  Please send your
generated Makefile along with your report.

For more up-to-date information, see L<http://www.makemaker.org>.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>


=cut

1;

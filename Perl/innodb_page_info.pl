#!/usr/bin/perl

###########################################
#    created by felixliang 2013-09-01     #
###########################################

use strict;
use warnings;
use IO::File;
use Getopt::Long qw(:config no_ignore_case bundling no_auto_abbrev);

# innodb page size
use constant INNODB_PAGE_SIZE => 1024 * 16;
use constant SPACE_ID => 34; #FIL_PAGE_ARCH_LOG_NO_OR_SPACE_ID
use constant FSP_SPACE_ID => 38; # TODO space_id saved in two place, why?

# Start of the data on the page inside the file Header of the page
use constant FIL_PAGE_DATA    => 38;
use constant FIL_PAGE_SPACE_OR_CHKSUM => 0;
# int the end of the innodb page
use constant FIL_PAGE_END_LSN_OLD_CHKSUM => 8;
# Start of the FILE_PAGE_OFFSET inside the file Header the page
use constant FIL_PAGE_OFFSET  => 4;
use constant FIL_PAGE_FILE_FLUSH_LSN => 26;
# Start of the FILE_PAGE_TYPE inside the file Header the page
use constant FIL_PAGE_TYPE    => 24;
# Types of an undo log segment */
use constant TRX_UNDO_INSERT  => 1;
use constant TRX_UNDO_UPDATE  => 2;
# Start of the PAGE_LEVEL inside the page Header
# level of the node in an index tree; the leaf level is the level 0
use constant PAGE_LEVEL       => 26; 

my $VERSION = "1.0";

my %innodb_page_type = (
        '0000' => 'Freshly Allocated Page', # TODO when specify --write-space-id, should we update the Freshly Page?
        '0002' => 'Undo Log Page',
        '0003' => 'File Segment inode',
        '0004' => 'Insert Buffer Free List',
        '0005' => 'Insert Buffer Bitmap',
        '0006' => 'System Page',
        '0007' => 'Transaction system Page',
        '0008' => 'File Space Header',
        '0009' => 'Extended MSG Page',
        '000a' => 'Uncompressed BLOB Page',
        '000b' => '1st compressed BLOB Page',
        '000c' => 'Subsequent compressed BLOB Page',
        '45bf' => 'B-tree Node'
);

my $ibd_file= undef;
my $verbose = undef;
GetOptions(
    'file|f:s'  =>  \$ibd_file,
    'verbose|v!'  =>  \$verbose,
    'help!'     => sub {print_usage() and exit; },
    'version|V!'    => sub {print_version() and exit; }
) || &print_usage();

# check the input params
die "must specify --file to specify ibd or ibdata file" if !$ibd_file;

sub print_version {
    print "innodb_page_info.pl ver $VERSION\n";
    return 1;
}

sub print_usage {
    my $info = [
        ["-f, --file=name" => "innodb ibd file name."],
        ["--version, -V" => "Get innodb_page_info.pl version."],
	["--verbose, -v" => "display all page info."],
        ["--help" => "Show usage information."]
    ];
    print_version();
    print "Usage: perl innodb_page_info.pl --file=/data1/mysqldata/data/db_test1/t1.ibd\n";
    print " when specify --verbose or -v option, display all page info.\n";
    foreach(@$info) {
        printf("%-40s%-60s\n",$_->[0],$_->[1]);
    }
    return 1;
}

sub read_page_from_file {
    my ($file, $offset, $length) = @_;
    my $page;

    open FH, $file or die "can't open(in binary mode) file $file";
    binmode(FH);
    seek FH, $offset, 0;
    read(FH, $page, $length);
    close FH;
    return $page;
}

sub read_value_from_page_unpack {
    my ($page, $offset, $length) = @_;
    my $value = substr $page, $offset, $length;
    return unpack("H*", $value);
}

sub main {
    my $hs_ret = {};
    # print "processing page info in file '$ibd_file' ...\n";
    my @file_stats = stat($ibd_file);
    my $t_file_size  = $file_stats[7];
    my $page_count = $t_file_size / INNODB_PAGE_SIZE;
    my $print_once = 1;

    for( my $i = 0; $i < $page_count; $i++ ) {
	my $page 		= read_page_from_file($ibd_file, $i * INNODB_PAGE_SIZE, INNODB_PAGE_SIZE);
        my $space_id            = read_value_from_page_unpack($page, SPACE_ID, 4);
        my $page_offset 	= read_value_from_page_unpack($page, FIL_PAGE_OFFSET, 4);
        my $page_type   	= read_value_from_page_unpack($page, FIL_PAGE_TYPE, 2);
        my $page_level 		= read_value_from_page_unpack($page, FIL_PAGE_DATA + PAGE_LEVEL, 2);
   	if( $verbose ) {
	  if( $page_type eq '45bf' ) {
	    printf ("page_offset[%s], page_type[%s], space_id[%s], page_level[%s]\n", $page_offset, $innodb_page_type{$page_type}, $space_id, $page_level);
	  }else{
	    printf ("page_offset[%s], page_type[%s], space_id[%s]\n", , $page_offset, $innodb_page_type{$page_type}, $space_id);
	  }
		
	}
	# do the stats and output the information
	if (not exists $hs_ret->{$page_type}) { 
	    $hs_ret->{$page_type} = 1;
        }else{	 
	    $hs_ret->{$page_type}++;
	}
    } 
    print "\n----------------- innodb page info ----------------\n";
    print "File $ibd_file, Total Page is $page_count\n";
    foreach my $type (keys %$hs_ret) {
	printf "Type %s, Cnt: %d\n", $innodb_page_type{$type}, $hs_ret->{$type};
    }
}

main;



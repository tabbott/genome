package Genome::Model::Tools::Somatic::FilterFalsePositives;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Somatic::FilterFalsePositives {
    is => 'Command',
    has => [

    ## INPUT/OUTPUT OPTIONS ##
        'bam_file' => {
            type => 'String',
            doc => 'BAM file in which to examine reads (usually tumor BAM)',
            is_input => 1,
        },
        'variant_file' => {
            type => 'String',
            is_input => 1,
            doc => 'List of variant positions in annotation format',
        },
        'output_file' => {
            type => 'String',
            is_input => 1,
            is_output => 1,
            doc => 'Filename for variants that pass filter',
        },
        'filtered_file' => {
            type => 'String',
            is_input => 1,
            is_optional => 1,
            is_output => 1,
            doc => 'Filename for variants that fail filter (optional)',
        },
        'reference' => {
            type => 'String',            
            is_optional => 1,
            is_input => 1,
            doc => 'Reference sequence to use.',
            example_values => [
                '/gscmnt/sata420/info/model_data/2857786885/build102671028/all_sequences.fa',
                '/gscmnt/sata420/info/reference_sequences/Homo_sapiens.NCBI36.45.dna.aml/all_sequences.fa',
            ],
        },
        ## CAPTURE FILTER OPTIONS ##
        'min_strandedness' => {
            type => 'String',
            default => '0.01',
            is_optional => 1,
            is_input => 1,
            doc => 'Minimum representation of variant allele on each strand',
        },
        'min_var_freq' => {
            type => 'String',
            default => '0.05',
            is_optional => 1,
            is_input => 1,
            doc => 'Minimum variant allele frequency',
        },
        'min_var_count' => {
            type => 'String',
            default => '4',
            is_optional => 1,
            is_input => 1,
            doc => 'Minimum number of variant-supporting reads',
        },
        'min_read_pos' => {
            type => 'String',
            default => '0.10',
            is_optional => 1,
            is_input => 1,
            doc => 'Minimum average relative distance from start/end of read',
        },
        'max_mm_qualsum_diff' => {
            type => 'String',
            default => '50',
            is_optional => 1,
            is_input => 1,
            doc => 'Maximum difference of mismatch quality sum between variant and reference reads (paralog filter)',
        },
        'max_var_mm_qualsum' => {
            type => 'String',
            is_optional => 1,
            is_input => 1,
            doc => 'Maximum mismatch quality sum of reference-supporting reads [try 60]',
        },
        'max_mapqual_diff' => {
            type => 'String',
            default => '30',
            is_optional => 1,
            is_input => 1,
            doc => 'Maximum difference of mapping quality between variant and reference reads',
        },
        'max_readlen_diff' => {
            type => 'String',
            default => '25',
            is_optional => 1,
            is_input => 1,
            doc => 'Maximum difference of average supporting read length between variant and reference reads (paralog filter)',
        },
        'min_var_dist_3' => {
            type => 'String',
            default => '0.20',
            is_optional => 1,
            is_input => 1,
            doc => 'Minimum average distance to effective 3prime end of read (real end or Q2) for variant-supporting reads',
        },
        'min_homopolymer' => {
            type => 'String',
            default => '5',
            is_optional => 1,
            is_input => 1,
            doc => 'Minimum length of a flanking homopolymer of same base to remove a variant',
        },
        'use_readcounts' => {
            type => 'String',
            is_input => 1,
            is_optional => 1,
            doc => 'Existing BAM-Readcounts file to save execution time',
        },
        ## WGS FILTER OPTIONS ##


        ## SHARED OPTIONS ##
        prepend_chr => {
            is => 'Boolean',
            default => '0',
            is_optional => 1,
            is_input => 1,
            doc => 'prepend the string "chr" to chromosome names. This is primarily used for external/imported bam files.',
        },
        verbose => {
            is => 'Boolean',
            default => '0',
            is_optional => 1,
            is_input => 1,
            doc => 'Print the filtering result for each site.',
        },
        # Make workflow choose 64 bit blades
        lsf_resource => {
            is_param => 1,
            default_value => 'rusage[mem=4000,tmp=1000] select[tmp>1000] span[hosts=1]',
        },
        lsf_queue => {
            is_param => 1,
            default_value => $ENV{GENOME_LSF_QUEUE_BUILD_WORKER},
        },
        skip => {
            is => 'Boolean',
            default => '0',
            is_input => 1,
            is_optional => 1,
            doc => "If set to true... this will do nothing! Fairly useless, except this is necessary for workflow.",
        },
        skip_if_output_present => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 0,
            doc => 'enable this flag to shortcut through annotation if the output_file is already present. Useful for pipelines.',
        },
        samtools_version => {
            is => 'Text',
            is_optional => 1,
            is_input => 1,
            doc => 'version of samtools to use',
        },
    ]
};

sub help_brief {
    return "This module uses detailed readcount information from bam-readcounts to filter likely false positives";
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
    EXAMPLE:
    gmt somatic filter-false-positives --variant-file somatic.snvs --bam-file tumor.bam --output-file somatic.snvs.fpfilter --filtered-file somatic.snvs.fpfilter.removed
EOS
}

sub help_detail {                           
    return <<EOS 
This module uses detailed readcount information from bam-readcounts to filter likely false positives.
It is HIGHLY recommended that you use the default settings, which have been comprehensively vetted.
Both capture and WGS projects now use the same filter and parameters.
For questions, e-mail Dan Koboldt (dkoboldt\@genome.wustl.edu) or Dave Larson (dlarson\@genome.wustl.edu)
EOS
}

sub execute {
    my $self = shift;

    if ($self->skip) {
        $self->status_message("Skipping execution: Skip flag set");
        return 1;
    }

    if (($self->skip_if_output_present)&&(-s $self->output_file)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }

    #test architecture to make sure we can run read count program
    unless (`uname -a` =~ /x86_64/) {
       $self->error_message("Must run on a 64 bit machine");
       die;
    }

    #check on BAM file
    unless(-e $self->bam_file) {
        $self->error_message("Tumor bam file: " . $self->bam_file . " does not exist");
        die;
    }

    unless(-e $self->bam_file . ".bai") {
        $self->error_message("Tumor bam must be indexed");
        die;
    }


    ## Run the FP filter. Note that both WGS and capture use the same filter now ##
    $self->run_filter();

}


##########################################################################################
# Capture filter for high-depth, lower-breadth datasets
# Contact: Dan Koboldt (dkoboldt@genome.wustl.edu)
##########################################################################################

sub run_filter {
    my $self = shift(@_);

    ## Determine the strandedness and read position thresholds ##

    my $min_read_pos = $self->min_read_pos;
    my $max_read_pos = 1 - $min_read_pos;
    my $min_var_freq = $self->min_var_freq;
    my $min_var_count = $self->min_var_count;

    my $min_strandedness = $self->min_strandedness;
    my $max_strandedness = 1 - $min_strandedness;

    my $max_mm_qualsum_diff = $self->max_mm_qualsum_diff;
    my $max_mapqual_diff = $self->max_mapqual_diff;
    my $max_readlen_diff = $self->max_readlen_diff;
    my $min_var_dist_3 = $self->min_var_dist_3;
    my $max_var_mm_qualsum = $self->max_var_mm_qualsum if($self->max_var_mm_qualsum);

    ## Reset counters ##

    my %stats = ();
    $stats{'num_variants'}  = $stats{'num_no_readcounts'} = $stats{'num_pass_filter'} = $stats{'num_no_allele'} = 0;
    $stats{'num_fail_varcount'} = $stats{'num_fail_varfreq'} = $stats{'num_fail_strand'} = $stats{'num_fail_pos'} = $stats{'num_fail_mmqs'} = $stats{'num_fail_mapqual'} = $stats{'num_fail_readlen'} = $stats{'num_fail_dist3'} = 0;
    $stats{'num_MT_sites_autopassed'} = $stats{'num_fail_homopolymer'} = 0;

    ## Open the output file ##

    my $temp_output_file = Genome::Sys->create_temp_file_path;
    my $ofh = Genome::Sys->open_file_for_writing($temp_output_file);
    unless($ofh) {
        $self->error_message("Unable to open " . $self->output_file . " for writing.");
        die;
    }

    ## Run BAM readcounts in batch mode to get read counts for all positions in file ##
    my $readcount_file;
    if($self->use_readcounts) {
        $readcount_file = $self->use_readcounts;
        unless(Genome::Sys->check_for_path_existence($readcount_file)) {
            $self->error_message('Supplied readcount file ' . $readcount_file . ' does not exist!');
            die;
        }

        $self->debug_message('Using existing BAM Readcounts from ' . $readcount_file . '...');
    } else {
        $self->debug_message('Running BAM Readcounts...');

        #First, need to create a variant list file to use for generating the readcounts.
        my $input = Genome::Sys->open_file_for_reading($self->variant_file);

        unless($input) {
            $self->error_message("Unable to open " . $self->variant_file . ".");
            die;
        }

        ## Build temp file for positions where readcounts are needed ##
        my ($tfh,$temp_path) = Genome::Sys->create_temp_file;
        unless($tfh) {
            $self->error_message("Unable to create temporary file.");
            die;
        }
        $temp_path =~ s/\:/\\\:/g;

        ## Print each line to file, prepending chromosome if necessary ##
        $self->debug_message('Printing variants to temp file...');
        while(my $line = $input->getline) {
            chomp $line;
            my ($chr, $start, $stop) = split /\t/, $line;
            next unless($start =~ /^\d+$/); #header line

            if ($self->prepend_chr) {
                $chr = "chr$chr";
                $chr =~ s/MT$/M/;
            };

            if($stop =~ /^\d+$/) { #annotation format
                print $tfh "$chr\t$start\t$stop\n";
            } else { #varscan format
                print $tfh "$chr\t$start\t$start\n";
            }
        }
        $tfh->close;
        close($input);

        $readcount_file = Genome::Sys->create_temp_file_path;

        my $cmd = $self->readcount_program() . " -b 15 " . $self->bam_file . " -l $temp_path";
        Genome::Sys->shellcmd(
            cmd => "$cmd > $readcount_file 2> /dev/null",
            input_files => [$self->bam_file],
            output_files => [$readcount_file],
        );
    }


    ## Open the readcounts file ##
    Genome::Sys->copy_file($readcount_file, $self->output_file . ".readcounts");

    my $readcount_fh = Genome::Sys->open_file_for_reading($readcount_file);
    $self->debug_message('Readcounts loaded');


    ## Open the filtered output file ##
    my $temp_filtered_file = Genome::Sys->create_temp_file_path();
    my $ffh = Genome::Sys->open_file_for_writing($temp_filtered_file);

    ## Reopen file for parsing ##
    my $input = Genome::Sys->open_file_for_reading($self->variant_file);

    ## Parse the variants file ##
    my $lineCounter = 0;

    while (<$input>) {
        chomp;
        my $line = $_;
        $lineCounter++;

        $stats{'num_variants'}++;

#        if($lineCounter <= 10) {
            (my $chrom, my $chr_start, my $chr_stop, my $ref, my $var) = split(/\t/, $line);
            next unless($chr_start =~ /^\d+$/); #header line
            unless($chr_stop =~ /^\d+$/) {
                my @rest;
                ($chrom, $chr_start, $ref, $var, @rest) = split(/\t/, $line); #varscan snp format doesn't list stop separately
                $chr_stop = $chr_start;

                #convert to annotation format
                $line = join("\t", $chrom, $chr_start, $chr_stop, $ref, $var, @rest);
            }

            $ref = uc($ref);
            $var = uc($var);

            my $query_string = "";

            if($self->prepend_chr) {
                $query_string = "chr" . $chrom . ":" . $chr_start . "-" . $chr_stop;
            } else {
                $query_string = $chrom . ":" . $chr_start . "-" . $chr_stop;
            }

            ## if the variant allele is an IUPAC code, convert it: ##

            if(!($var =~ /[ACGT]/)) {
                $var = $self->iupac_to_base($ref, $var);
            }

            if($var =~ /[ACGT]/) {

                ## Skip MT chromosome sites,w hich almost always pass ##
                if($chrom eq "MT" || $chrom eq "chrMT") {
                    ## Auto-pass it to increase performance ##
                    $stats{'num_MT_sites_autopassed'}++;
                    print $ofh "$line\n";
#                } elsif($self->prepend_chr && $chrom =~ "random") {
#                    $stats{'num_random_sites_autopassed'}++;
#                    print $ofh "$line\n";
                } else {
                    ## Run Readcounts ##
#                    my $cmd = $self->readcount_program() . " -b 15 " . $self->bam_file . " $query_string";
#                    my $readcounts = `$cmd`;
#                    chomp($readcounts) if($readcounts);

                    my $readcounts;
                    my $search_chrom = $chrom;
                    $search_chrom = "chr$chrom" if $self->prepend_chr;
                    unless($readcounts = $self->_get_readcount_line($readcount_fh, $search_chrom,$chr_start)){
                        die $self->error_message("Failed to find readcount data for: ".$search_chrom."\t".$chr_start);
                    }



                    ## Parse the results for each allele ##

                    my $ref_result = $self->read_counts_by_allele($readcounts, $ref);
                    my $var_result = $self->read_counts_by_allele($readcounts, $var);

                    if($ref_result && $var_result) {
                        ## Parse out the bam-readcounts details for each allele. The fields should be: ##
                        #num_reads : avg_mapqual : avg_basequal : avg_semq : reads_plus : reads_minus : avg_clip_read_pos : avg_mmqs : reads_q2 : avg_dist_to_q2 : avgRLclipped : avg_eff_3'_dist
                        my ($ref_count, $ref_map_qual, $ref_base_qual, $ref_semq, $ref_plus, $ref_minus, $ref_pos, $ref_subs, $ref_mmqs, $ref_q2_reads, $ref_q2_dist, $ref_avg_rl, $ref_dist_3) = split(/\t/, $ref_result);
                        my ($var_count, $var_map_qual, $var_base_qual, $var_semq, $var_plus, $var_minus, $var_pos, $var_subs, $var_mmqs, $var_q2_reads, $var_q2_dist, $var_avg_rl, $var_dist_3) = split(/\t/, $var_result);

                        my $ref_strandedness = my $var_strandedness = 0.50;
                        $ref_dist_3 = 0.5 if(!$ref_dist_3);

                        ## Use conservative defaults if we can't get mismatch quality sums ##
                        $ref_mmqs = 50 if(!$ref_mmqs);
                        $var_mmqs = 0 if(!$var_mmqs);
                        my $mismatch_qualsum_diff = $var_mmqs - $ref_mmqs;

                        ## Determine map qual diff ##

                        my $mapqual_diff = $ref_map_qual - $var_map_qual;


                        ## Determine difference in average supporting read length ##

                        my $readlen_diff = $ref_avg_rl - $var_avg_rl;


                        ## Determine ref strandedness ##

                        if(($ref_plus + $ref_minus) > 0) {
                            $ref_strandedness = $ref_plus / ($ref_plus + $ref_minus);
                            $ref_strandedness = sprintf("%.2f", $ref_strandedness);
                        }

                        ## Determine var strandedness ##

                        if(($var_plus + $var_minus) > 0) {
                            $var_strandedness = $var_plus / ($var_plus + $var_minus);
                            $var_strandedness = sprintf("%.2f", $var_strandedness);
                        }

                        if($var_count && ($var_plus + $var_minus)) {
                            ## We must obtain variant read counts to proceed ##

                            my $var_freq = $var_count / ($ref_count + $var_count);

                            ## FAILURE 1: READ POSITION ##
                            if(($var_pos < $min_read_pos)) { # || $var_pos > $max_read_pos)) {
                                print $ffh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tReadPos<$min_read_pos\n";
                                print "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tReadPos<$min_read_pos\n"if ($self->verbose);
                                $stats{'num_fail_pos'}++;
                            }

                            ## FAILURE 2: Variant is strand-specific but reference is NOT strand-specific ##
                            elsif(($var_strandedness < $min_strandedness || $var_strandedness > $max_strandedness) && ($ref_strandedness >= $min_strandedness && $ref_strandedness <= $max_strandedness)) {
                                ## Print failure to output file if desired ##
                                print $ffh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tStrandedness: Ref=$ref_strandedness Var=$var_strandedness\n";
                                print "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tStrandedness: Ref=$ref_strandedness Var=$var_strandedness\n"if ($self->verbose);
                                $stats{'num_fail_strand'}++;
                            }

                            ## FAILURE : Variant allele count does not meet minimum ##
                            elsif($var_count < $min_var_count) {
                                print $ffh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tVarCount:$var_count\n";
                                print "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tVarCount:$var_count\n" if ($self->verbose);
                                $stats{'num_fail_varcount'}++;
                            }

                            ## FAILURE : Variant allele frequency does not meet minimum ##
                            elsif($var_freq < $min_var_freq) {
                                print $ffh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tVarFreq:$var_freq\n";
                                print "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tVarFreq:$var_freq\n" if ($self->verbose);
                                $stats{'num_fail_varfreq'}++;
                            }

                            ## FAILURE 3: Paralog filter for sites where variant allele mismatch-quality-sum is significantly higher than reference allele mmqs
                            elsif($mismatch_qualsum_diff> $max_mm_qualsum_diff) {
                                ## Print failure to output file if desired ##
                                print $ffh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tMismatchQualsum:$var_mmqs-$ref_mmqs=$mismatch_qualsum_diff\n";
                                print "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tMismatchQualsum:$var_mmqs-$ref_mmqs=$mismatch_qualsum_diff" if ($self->verbose);
                                $stats{'num_fail_mmqs'}++;
                            }

                            ## FAILURE 4: Mapping quality difference exceeds allowable maximum ##
                            elsif($mapqual_diff > $max_mapqual_diff) {
                                print $ffh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tMapQual:$ref_map_qual-$var_map_qual=$mapqual_diff\n";
                                print "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tMapQual:$ref_map_qual-$var_map_qual=$mapqual_diff" if ($self->verbose);
                                $stats{'num_fail_mapqual'}++;
                            }

                            ## FAILURE 5: Read length difference exceeds allowable maximum ##
                            elsif($readlen_diff > $max_readlen_diff) {
                                print $ffh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tReadLen:$ref_avg_rl-$var_avg_rl=$readlen_diff\n";
                                print "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tReadLen:$ref_avg_rl-$var_avg_rl=$readlen_diff" if ($self->verbose);
                                $stats{'num_fail_readlen'}++;
                            }

                            ## FAILURE 5: Read length difference exceeds allowable maximum ##
                            elsif($var_dist_3 < $min_var_dist_3) {
                                print $ffh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tVarDist3:$var_dist_3\n";
                                print "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tVarDist3:$var_dist_3\n" if ($self->verbose);
                                $stats{'num_fail_dist3'}++;
                            }

                            elsif($self->fails_homopolymer_check($self->reference, $self->min_homopolymer, $chrom, $chr_start, $chr_stop, $ref, $var)) {
                                print $ffh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tHomopolymer\n";
                                print "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tHomopolymer\n" if ($self->verbose);
                                $stats{'num_fail_homopolymer'}++;
                            }

                            elsif($max_var_mm_qualsum && $var_mmqs > $max_var_mm_qualsum) {
                                print $ffh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tVarMMQS: $var_mmqs > $max_var_mm_qualsum\n";
                                print "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tVarMMQS: $var_mmqs > $max_var_mm_qualsum\n" if ($self->verbose);
                                $stats{'num_fail_var_mmqs'}++;
                            }

                            ## SUCCESS: Pass Filter ##
                            else {
                                $stats{'num_pass_filter'}++;
                                ## Print output, and append strandedness information ##
                                print $ofh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\t$ref_mmqs\t$var_mmqs\t$mismatch_qualsum_diff\t$ref_dist_3\t$var_dist_3\t$ref_avg_rl\t$var_avg_rl\n";
                                print "$line\t\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tPASS\n" if($self->verbose);
                            }
                        } else {
                            $stats{'num_no_readcounts'}++;
                            print $ffh "$line\tno_reads\n" if($self->filtered_file);
                            print "$chrom\t$chr_start\t$chr_stop\t$ref\t$var\tFAIL no reads in $var_result\n" if($self->verbose);
                        }
                    } else {
#                       $self->error_message("Unable to get read counts for $ref/$var at position $chrom\t$chr_start\t$chr_stop");
#                       die;
                    }
                }
            } else {
                print $ffh "$line\tno_allele\n" if($self->filtered_file);
                print "$line\tFailure: Unable to determine allele!\n" if($self->verbose);
                $stats{'num_no_allele'}++;
            }
#       }
    }

    close($input);
    close($ofh);
    close($ffh);

    my $filtered_file = $self->output_file . ".removed";
    $filtered_file = $self->filtered_file if($self->filtered_file);

    Genome::Sys->copy_file($temp_output_file, $self->output_file);
    Genome::Sys->copy_file($temp_filtered_file, $filtered_file);

    print $stats{'num_variants'} . " variants\n";
    print $stats{'num_MT_sites_autopassed'} . " MT sites were auto-passed\n";
    print $stats{'num_random_sites_autopassed'} . " chrN_random sites were auto-passed\n" if($stats{'num_random_sites_autopassed'});
    print $stats{'num_no_allele'} . " failed to determine variant allele\n";
    print $stats{'num_no_readcounts'} . " failed to get readcounts for variant allele\n";
    print $stats{'num_fail_pos'} . " had read position < $min_read_pos\n";
    print $stats{'num_fail_strand'} . " had strandedness < $min_strandedness\n";
    print $stats{'num_fail_varcount'} . " had var_count < $min_var_count\n";
    print $stats{'num_fail_varfreq'} . " had var_freq < $min_var_freq\n";

    print $stats{'num_fail_mmqs'} . " had mismatch qualsum difference > $max_mm_qualsum_diff\n";
    print $stats{'num_fail_var_mmqs'} . " had variant MMQS > $max_var_mm_qualsum\n" if($stats{'num_fail_var_mmqs'});
    print $stats{'num_fail_mapqual'} . " had mapping quality difference > $max_mapqual_diff\n";
    print $stats{'num_fail_readlen'} . " had read length difference > $max_readlen_diff\n";
    print $stats{'num_fail_dist3'} . " had var_distance_to_3' < $min_var_dist_3\n";
    print $stats{'num_fail_homopolymer'} . " were in a homopolymer of " . $self->min_homopolymer . " or more bases\n";

    print $stats{'num_pass_filter'} . " passed the strand filter\n";

    return 1;
}

#############################################################
# Read_Counts_By_Allele - parse out readcount info for an allele
#
#############################################################

sub fails_homopolymer_check {
    (my $self, my $reference, my $min_homopolymer, my $chrom, my $chr_start, my $chr_stop, my $ref, my $var) = @_;

    ## Auto-pass large indels ##

    my $indel_size = length($ref);
    $indel_size = length($var) if(length($var) > $indel_size);

    return(0) if($indel_size > 2);

    ## Build strings of homopolymer bases ##
    my $homoRef = $ref x $min_homopolymer;
    my $homoVar = $var x $min_homopolymer;
#    my $homoA = 'A' x $min_homopolymer;
#    my $homoC = 'C' x $min_homopolymer;
#    my $homoG = 'G' x $min_homopolymer;
#    my $homoT = 'T' x $min_homopolymer;

    ## Build a query string for the homopolymer check ##

    my $query_string = "";

    if($self->prepend_chr) {
        $query_string = "chr" . $chrom . ":" . ($chr_start - $min_homopolymer) . "-" . ($chr_stop + $min_homopolymer);
    } else {
        $query_string = $chrom . ":" . ($chr_start - $min_homopolymer) . "-" . ($chr_stop + $min_homopolymer);
    }

    my $samtools_path = Genome::Model::Tools::Sam->path_for_samtools_version($self->samtools_version);
    my $sequence = `$samtools_path faidx $reference $query_string | grep -v \">\"`;
    chomp($sequence);

    if($sequence) {
        if($sequence =~ $homoVar) { #$sequence =~ $homoRef || {
            print join("\t", $chrom, $chr_start, $chr_stop, $ref, $var, "Homopolymer: $sequence") . "\n" if($self->verbose);
            return($sequence);
        }
    }

    return(0);
}

#############################################################
# Readcount_Program - the path to BAM-readcounts
#
#############################################################

sub readcount_program {
    my $self = shift;
    my $reference = $self->reference;
    return "bam-readcount0.4 -f $reference";
#    return "/gscuser/dlarson/src/genome/bam-readcount/bin/bam-readcount -f $reference";
}


#############################################################
# Read_Counts_By_Allele - parse out readcount info for an allele
#
#############################################################

sub read_counts_by_allele {
    my $self = shift;
    (my $line, my $allele) = @_;

    my @lineContents = split(/\t/, $line);
    my $numContents = @lineContents;

    for(my $colCounter = 5; $colCounter < $numContents; $colCounter++) {
        my $this_allele = $lineContents[$colCounter];
        my @alleleContents = split(/\:/, $this_allele);
        if($alleleContents[0] eq $allele) {
            my $numAlleleContents = @alleleContents;

            return("") if($numAlleleContents < 8);

            my $return_string = "";
            my $return_sum = 0;
            for(my $printCounter = 1; $printCounter < $numAlleleContents; $printCounter++) {
                $return_sum += $alleleContents[$printCounter];
                $return_string .= "\t" if($return_string);
                $return_string .= $alleleContents[$printCounter];
            }

            return($return_string);

#            if($return_sum) {
#                return($return_string);
#            } else {
#                return("");
#            }
        }
    }

    return("");
}

#############################################################
# ParseBlocks - takes input file and parses it
#
#############################################################

sub iupac_to_base {
    my $self = shift;
    (my $allele1, my $allele2) = @_;

    return($allele2) if($allele2 eq "A" || $allele2 eq "C" || $allele2 eq "G" || $allele2 eq "T");

    if($allele2 eq "M") {
        return("C") if($allele1 eq "A");
        return("A") if($allele1 eq "C");
        return("A");    ## Default for triallelic variant
    } elsif($allele2 eq "R") {
        return("G") if($allele1 eq "A");
        return("A") if($allele1 eq "G");
        return("A");     ## Default for triallelic variant
    } elsif($allele2 eq "W") {
        return("T") if($allele1 eq "A");
        return("A") if($allele1 eq "T");
        return("A");    ## Default for triallelic variant
    } elsif($allele2 eq "S") {
        return("C") if($allele1 eq "G");
        return("G") if($allele1 eq "C");
        return("C");    ## Default for triallelic variant
    } elsif($allele2 eq "Y") {
        return("C") if($allele1 eq "T");
        return("T") if($allele1 eq "C");
        return("C");    ## Default for triallelic variant
    } elsif($allele2 eq "K") {
        return("G") if($allele1 eq "T");
        return("T") if($allele1 eq "G");
        return("G");    ## Default for triallelic variant
    }

    return($allele2);
}

# This method scans the lines of the readcount file until the matching line is found
sub _get_readcount_line {
    my $self = shift;
    $DB::single =1 ;
    my ($readcount_fh,$chr,$start) = @_;
    while( my $line = $readcount_fh->getline){
        chomp $line;
        my ($rc_chr,$rc_pos) = split "\t", $line;
        if(($chr eq $rc_chr)&&($start == $rc_pos)){
            return $line;
        }
    }
    return;
}

1;

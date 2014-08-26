#lumpy.pm
#this program is ment to run the bam files specified.  it will run both a paired end and a single read file before depositing the data into a histo file in the lumpy-sv_results dir

package Genome::Model::Tools::DetectVariants2::Lumpy;
use warnings;
use strict;

use Genome;
use File::Basename;
use IPC::System::Simple;

my @FULL_CHR_LIST = (1 .. 22, 'X', 'Y', 'MT');

class Genome::Model::Tools::DetectVariants2::Lumpy {is => 'Genome::Model::Tools::DetectVariants2::Detector',};

sub _detect_variants {
    my $self = shift;

    my @final_paired_end_parameters;
    my @final_split_read_parameters;
    for my $input_bam ($self->aligned_reads_input, $self->control_aligned_reads_input) {
        next unless defined($input_bam);
        for my $bam (split_bam_by_readgroup($input_bam)) {
            if ($self->paired_end_base_params) {
                push(@final_paired_end_parameters, $self->paired_end_parameters_for_bam($bam));
            }
            if ($self->split_read_base_params) {
                push(@final_split_read_parameters, $self->split_read_parameters_for_bam($bam));
            }
        }
    }
    my $paired_end_parameters_string = join(' ', @final_paired_end_parameters);
    my $split_read_parameters_string = join(' ', @final_split_read_parameters);

    my $run = Genome::Sys->shellcmd(
        cmd                          => $self->create_command($paired_end_parameters_string, $split_read_parameters_string),
        output_files                 => [$self->_sv_staging_output],
        allow_zero_size_output_files => 1,
    );
}

sub split_bam_by_readgroup {
    my $bam_file  = shift;

    my $split_dir = Genome::Sys->create_temp_directory();
    my $split_bam_basename = File::Spec->join($split_dir, 'split_bam');
    my $command = "bamtools split -in $bam_file -stub $split_bam_basename -tag RG";
    Genome::Sys->shellcmd(cmd => $command);
    return glob("$split_bam_basename*");
}

sub extract_paired_end_reads {
    my $bam = shift;

    my $filtered_bam  = Genome::Sys->create_temp_file_path();
    my $command = "samtools view -b -F 1294 $bam -o $filtered_bam";
    Genome::Sys->shellcmd(
        cmd                          => $command,
        allow_zero_size_output_files => 1,
    );
    return $filtered_bam;
}

sub extract_split_reads {
    my $self = shift;
    my $bam = shift;
    my $filtered_bam = Genome::Sys->create_temp_file_path();
    my $extract_split_reads_bwamen_script = $self->lumpy_script_for_extract_split_reads_bwamem();
    my $command = join(
        '|',
        "samtools view -h $bam",
        "$extract_split_reads_bwamen_script -i stdin",
        "java -Xmx8g -XX:MaxPermSize=256m -cp /gsc/scripts/lib/java/samtools/picard-tools-1.82/SamFormatConverter.jar net.sf.picard.sam.SamFormatConverter I=/dev/stdin O=$filtered_bam"
    );
    Genome::Sys->shellcmd(
        cmd                          => $command,
        allow_zero_size_output_files => 1,
    );
    return $filtered_bam;
}

sub paired_end_parameters_for_bam {
    my $self = shift;
    my $bam  = shift;

    my $filtered_bam = extract_paired_end_reads($bam);
    my %metrics = $self->calculate_metrics($bam);

    return sprintf(
        ' -pe bam_file:%s,histo_file:%s,mean:%s,stdev:%s,read_length:150,%s',
        $filtered_bam,
        $metrics{histogram},
        $metrics{mean},
        $metrics{standard_deviation},
        $self->paired_end_base_params
    );
}

sub split_read_parameters_for_bam {
    my $self = shift;
    my $bam = shift;

    my $filtered_bam = $self->extract_split_reads($bam);
    return sprintf(
        " -sr bam_file:%s,%s",
        $filtered_bam,
        $self->split_read_base_params
    );
}

sub calculate_metrics {
    my $self = shift;
    my $bam  = shift;

    my $histogram = Genome::Sys->create_temp_file_path();
    my $pairend_distro_script = $self->lumpy_script_for_pairend_distro;
    my @commands   = qq(samtools view $bam | tail -n+100 | $pairend_distro_script -r1 100 -X 4 -N 10000 -o $histogram);
    my $output = IPC::System::Simple::capture(@commands);

    if ($output =~ m/mean:([-+]?[0-9]*\.?[0-9]*)\s+stdev:([-+]?[0-9]*\.?[0-9]*)/) {
        my $mean = $1;
        my $standard_deviation = $2;
        my %metrics = (
            mean               => $mean,
            standard_deviation => $standard_deviation,
            histogram          => $histogram,
        );
        return %metrics;
    }
    else {
        die "ERROR couldn't determine mean and standard deviation: $output";
    }
}

sub split_read_base_params {
    my $self = shift;
    return $self->params_hash->{sr};
}

sub paired_end_base_params {
    my $self = shift;
    return $self->params_hash->{pe};
}

sub lumpy_base_params {
    my $self = shift;
    my $lumpy_base_params = $self->params_hash->{lp};
    $lumpy_base_params =~ s/[,:]/ /g;
    return $lumpy_base_params;
}

sub params_hash {
    my $self = shift;
    my %parameters;
    foreach my $param (split('//', $self->params)) {
        if ($param =~ m/^\-(pe|sr|lp),(.*)$/) {
            $parameters{$1} = $2;
        }
        else {
            die $self->error_message("The specified parameter is malformed: ($param)");
        }
    }
    return \%parameters;
}

sub create_command {
    my $self = shift;
    my $paired_end_commands = shift;
    my $split_read_commands = shift;

    my $lumpy_base_params = $self->lumpy_base_params;
    my $executable_path   = $self->lumpy_command;
    my $output_file       = $self->_sv_staging_output;
    return "$executable_path $lumpy_base_params $paired_end_commands $split_read_commands > $output_file";
}

sub lumpy_directory {
    my $self    = shift;
    my $version = $self->version();

    return _lumpy_directory($version);
}

sub _lumpy_directory {
    my $version = shift;
    return File::Spec->catdir(File::Spec->rootdir, "usr", "lib", "lumpy" . "$version");
}

sub lumpy_command {
    my $self = shift;
    return File::Spec->catfile($self->lumpy_directory(), "bin", "lumpy");
}

sub lumpy_scripts_directory {
    my $self = shift;
    return File::Spec->catfile($self->lumpy_directory(), 'scripts');
}

sub lumpy_script_for {
    my $self        = shift;
    my $script_name = shift;

    die "no script name given" if not $script_name;
    my $script_location = File::Spec->catfile($self->lumpy_scripts_directory(), "$script_name");

    die "script does not exist $script_location" if not -e $script_location;
    return $script_location;
}

sub lumpy_script_for_extract_split_reads_bwamem {
    my $self = shift;
    return $self->lumpy_script_for("extractSplitReads_BwaMem");
}

sub lumpy_script_for_pairend_distro {
    my $self = shift;
    return $self->lumpy_script_for("pairend_distro.py");
}

sub has_version {
    my $self    = shift;
    my $version = shift;
    if (-d _lumpy_directory($version)) {
        return 1;
    }
    else {
        return 0;
    }
}

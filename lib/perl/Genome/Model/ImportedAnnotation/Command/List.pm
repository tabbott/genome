package Genome::Model::ImportedAnnotation::Command::List;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::Model::ImportedAnnotation::Command::List {
    is => 'Genome::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Model::ImportedAnnotation' 
        },
        show => { default_value => 'id,name,species_name' },
    ],
    doc => 'list genome models',
};

sub sub_command_sort_position { 3 }

sub Xhelp_brief { shift->__meta__->doc }

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/List.pm $
#$Id: List.pm 40876 2008-11-11 22:48:58Z ebelter $

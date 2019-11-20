#!/usr/bin/perl
#
# @File rule.pm
# @Author vitalys
# @Created Aug 1, 2016 9:05:15 AM
#

package rule;
{
    use strict;
    use JSON::XS;
    use Data::Dumper;
#    use File::Glob;
    use File::Find;
    
    use constant DEFAULT_CONFIG    => '/var/packages/robocopy/etc/rules.conf';
    use constant CONFIG_FIELDS => {
                    'id' => 0,
                    'priority' => 0,
                    'src_dir' => '',
                    'src_ext' => '',
                    'dest_folder' => '',
                    'dest_dir' => '',
                    'dest_file' => '',
                    'dest_ext' => '',
                    'description' => '',
                    'src_remove' => 0
            };
    1;

    sub new {
        my($class, $args) = @_;
        # создаем хэш
        my $self = init($args);
        $self->{id} = int(rand(4294967296));
        # хэш превращается, превращается... в объект
        bless $self, $class;
       
        return $self;
    }

    sub parse {
        my($args) = @_;
        # создаем хэш
        my $self = init($args);
#        $self->{id} = int(rand(4294967296)) unless exists $self->{id};

        # хэш превращается, превращается... в объект
        bless $self, __PACKAGE__;
       
        return $self;
    }

    sub init
    {
        my($args) = @_;
        $args = {} unless ref($args) eq 'HASH';
        my $self = { };
#        print Dumper $self;
        foreach my $key (keys %{CONFIG_FIELDS()}) {
            if (exists($args->{$key})) {
                $self->{$key} = (is_number_field($key) ? int($args->{$key}) : $args->{$key});
            }
            else {
                $self->{$key} = CONFIG_FIELDS->{$key};
            }
        }
        return $self;
    }

    sub set
    {
        my ($self, $args) = @_;
        return unless ref($args) eq 'HASH';
        foreach my $key (keys %{CONFIG_FIELDS()}) {
            next if $key eq 'id';
            if (exists($args->{$key})) {
                $self->{$key} = (is_number_field($key) ? int($args->{$key}) : $args->{$key});
            }
        }
    }
    
    
    sub TO_JSON {
        return { %{ shift() } };
    }
    
    #####################################################################
    # properties
    sub is_valid
    {
        my ($self) = @_;
        return 0 unless exists $self->{id};
        return 1;
    }
    
    sub id {
        my ($self) = @_;
        return $self->{id};
    }

    sub priority {
        my ($self, $value) = @_;
        $self->{priority} = int($value) if defined $value;
        return 0 unless defined $self->{priority};
        return int($self->{priority});
    }

    sub src_dir {
        my ($self, $value) = @_;
        $self->{src_dir} = $value if defined $value;
        return '' unless defined $self->{src_dir};
        return $self->{src_dir};
    }
    
    sub src_ext {
        my ($self, $value) = @_;
        $self->{src_ext} = $value if defined $value;
        return '' unless defined $self->{src_ext};
        return $self->{src_ext};
    }
    
    sub dest_folder {
        my ($self, $value) = @_;
        $self->{dest_folder} = $value if defined $value;
        return '' unless defined $self->{dest_folder};
        return $self->{dest_folder};
    }
    
    sub dest_dir {
        my ($self, $value) = @_;
        $self->{dest_dir} = $value if defined $value;
        return '' unless defined $self->{dest_dir};
        return $self->{dest_dir};
    }
    sub dest_file {
        my ($self, $value) = @_;
        $self->{dest_file} = $value if defined $value;
        return '' unless defined $self->{dest_file};
        return $self->{dest_file};
    }
    
    sub dest_ext {
        my ($self, $value) = @_;
        $self->{dest_ext} = $value if defined $value;
        return '' unless defined $self->{dest_ext};
        return $self->{dest_ext};
    }
    sub description {
        my ($self, $value) = @_;
        $self->{description} = $value if defined $value;
        return '' unless defined $self->{description};
        return $self->{description};
    }
    
    sub src_remove {
        my ($self, $value) = @_;
        $self->{src_remove} = int($value) if defined $value;
        return 0 unless defined $self->{src_remove};
        return $self->{src_remove};
    }
    
 
    #####################################################################
    #
    sub load_list
    {
        my ($file, $sort_name) = @_;
        $file = DEFAULT_CONFIG unless defined $file;
        return () unless -e $file;
        my $cgf_text = do {
            local $/ = undef;
            open my $fh, "<", $file || die "could not open $file: $!";
            <$fh>;
        };
        my $cfg = decode_json $cgf_text;
        my $result = [];

        if (ref($cfg) eq 'ARRAY') {
            if (defined($sort_name)) {
                if (is_number_field($sort_name)) {
                    @$cfg = sort {$a->{$sort_name} <=> $b->{$sort_name}} @$cfg;
                }
                else {
                    @$cfg = sort {$a->{$sort_name} cmp $b->{$sort_name}} @$cfg;
                }
            }
            foreach my $item (@$cfg) {
                my $rule = init($item);
                bless $rule, __PACKAGE__;
                push @$result, $rule;
            }
        }
        return $result;
    }
    
    sub save_list
    {
        my ($cfg, $file) = @_;
        return unless ref($cfg) eq "ARRAY";
        $file = DEFAULT_CONFIG unless defined $file;
        open my $fh, ">", $file || die "could not open $file: $!";
        print $fh JSON::XS->new->utf8->convert_blessed->encode($cfg);
        close $fh;
    }
    
    sub obj_to_json
    {
        my $obj = shift;
        return JSON::XS->new->utf8->convert_blessed->encode($obj);
    }
    
    sub demo_list
    {
        my ($share) = @_;
        $share = 'photo' unless defined $share;
        return [
            new rule({
                'priority' => 1,
                'src_dir' => 'DCIM',
                'src_ext' => 'jpg',
                'src_remove' => 0,
                'dest_folder'=>$share,
                'dest_dir'=>'image/%Y-%m-%d',
                'dest_file'=>'',
                'dest_ext'=>'',
                'description' => 'Copy images'
            }),
            new rule({
                'priority' => 2,
                'src_dir' => 'MP_ROOT',
                'src_ext' => 'mpg',
                'src_remove' => 0,
                'dest_folder'=>$share,
                'dest_dir'=>'video/%Y-%m-%d',
                'dest_file'=>'',
                'dest_ext'=>'',
                'description' => 'Copy videos'
            }),
            new rule({
                'priority' => 3,
                'src_dir' => '',
                'src_ext' => '3gp',
                'src_remove' => 0,
                'dest_folder'=>$share,
                'dest_dir'=>'video/%Y-%m-%d',
                'dest_file'=>'',
                'dest_ext'=>'',
                'description' => 'Copy mobile videos'
            }),
            new rule({
                'priority' => 4,
                'src_dir' => '',
                'src_ext' => '',
                'src_remove' => 0,
                'dest_folder'=>$share,
                'dest_dir'=>'other/%Y-%m-%d',
                'dest_file'=>'',
                'dest_ext'=>'',
                'description' => 'Copy others'
            })
        ];
    }

    
    sub is_number_field
    {
        my $key = shift;
        return undef unless exists CONFIG_FIELDS->{$key};
        return 1 if CONFIG_FIELDS->{$key} ne '';
        return 0;
    }
    
    sub create_demo
    {
        my $cfg = demo_list(@_);
        save_list($cfg);
    }
}

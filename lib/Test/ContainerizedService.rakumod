use v6.d;
use Test;
use Test::ContainerizedService::Spec;

# Mapping of names passed to test-service to the module name to require and
# (matching) class to use.
my constant %specs =
        'postgres' => 'Test::ContainerizedService::Spec::Postgres';

#| Run tests in the provided body with the specified service.
sub test-service(Str $service-id, &body, Str :$tag, *%options) is export {
    with %specs{$service-id} -> $module {
        # Load the specification module.
        require ::($module);
        my $spec-class = ::($module);
        my Test::ContainerizedService::Spec $spec = $spec-class.new(|%options);

        # Form the image name and try to obtain it.
        my $image = $spec.docker-container ~ ":" ~ ($tag // $spec.default-docker-tag);
        my ($success, $error) = docker-pull-image($image);
        unless $success {
            diag $error;
            skip "Could not obtain container image $image";
        }

        # Now run the container and, when ready, tests.
        my $test-error;
        react {
            my $ran-tests = False;
            my $name = "test-service-$*PID";
            my $container = Proc::Async.new: 'docker', 'run', '-t', '--rm',
                    $spec.docker-options, '--name', $name, $image,
                    $spec.docker-command-and-arguments;
            whenever $container.stdout.lines {
                # Discard
            }
            whenever $container.stderr.lines {
                diag "Container: $_";
            }
            whenever $container.ready {
                QUIT {
                    default {
                        skip "Failed to run test service container: $_.message()";
                        done;
                    }
                }
                my $ready = $spec.ready(:$name);
                whenever Promise.anyof($ready, Promise.in(60)) {
                    if $ready {
                        $ran-tests = 1;
                        body($spec.service-data);
                        CATCH {
                            default {
                                $test-error = $_;
                            }
                        }
                    }
                    else {
                        skip "Test container did not become ready in time";
                    }
                    docker-stop($name);
                    $container.kill;
                    done;
                }
            }
            whenever $container.start {
                unless $ran-tests {
                    skip "Container failed before starting tests";
                    done;
                }
            }
        }
        .rethrow with $test-error;
    }
    else {
        die "No service specification for '$service-id'; available are: " ~
            %specs.keys.join(", ")
    }
}

#| Tries to pull a docker image.
sub docker-pull-image(Str $image) {
    my Str $error = '';
    react {
        my $proc = Proc::Async.new('docker', 'pull', $image);
        whenever $proc.stdout {}
        whenever $proc.stderr {
            $error ~= $_;
        }
        whenever $proc.start -> $result {
            if $result.exitcode != 0 {
                $error = "Exit code $result.exitcode()\n$error";
            }
            else {
                $error = Nil;
            }
        }
    }
    (!$error, $error)
}

#| Sends the stop command to a docker container.
sub docker-stop(Str $name --> Nil) {
    my $proc = Proc::Async.new('docker', 'stop', $name);
    .tap for $proc.stdout, $proc.stderr;
    try sink await $proc.start;
}

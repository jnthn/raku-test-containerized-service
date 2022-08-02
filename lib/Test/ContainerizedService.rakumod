use v6.d;
use Dev::ContainerizedService :get-spec, :docker;
use Dev::ContainerizedService::Spec;
use Test;

#| Run tests in the provided body with the specified service.
sub test-service(Str $service-id, &body, Str :$tag, *%options) is export {
    # Resolve the service spec and instantiate.
    my $spec-class = get-spec($service-id);
    my Dev::ContainerizedService::Spec $spec = $spec-class.new(|%options);

    # Form the image name and try to obtain it.
    my $image = $spec.docker-container ~ ":" ~ ($tag // $spec.default-docker-tag);
    my $outcome = docker-pull-image($image);
    if $outcome ~~ Failure {
        diag $outcome.exception.message;
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

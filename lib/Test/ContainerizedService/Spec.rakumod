use v6.d;

#| Specification of a containerized service. This role is done by each service
#| that we want to provide a test container for. Classes implementing this role
#| should add further public attributes for user-configurable options, and can
#| use private ones for state produced when working out the container options
#| (for example, generated ports or throw-away passwords) that should be used
#| later when producing the service options.
role Test::ContainerizedService::Spec {
    #| Specify the docker container name.
    method docker-container(--> Str) { ... }

    #| The default docker tag.
    method default-docker-tag(--> Str) { ... }

    #| Options to pass to `docker`.
    method docker-options(--> Positional) { [] }

    #| Command and argument to pass to `docker`.
    method docker-command-and-arguments(--> Positional) { [] }

    #| Returns a Promise that will be kept when the service is ready, or
    #| broken if it cannot be determined ready. The container name is
    #| passed in.
    method ready(Str :$name --> Promise) { return Promise.kept(True) }

    #| Gets a hash of information about the started service to pass to the
    #| test block (for example, with connection information).
    method service-data(--> Associative) { ... }

    #| The first time this is called with a particular key, it generates a
    #| port number, picking one that is currently free. (This is inherently
    #| a bit racy, and some mitigations are done to try and avoid conflicts
    #| in parallel tests.) If the key was already passed, then the same
    #| port number is returned. This is useful for
    method generate-port(--> Int) {
        for ^100 {
            # Pick a random port between 26000 and 30000, to reduce the
            # risk of collisions.
            my $candidate = 26000 + (^4000).pick;
            my $try-conn = IO::Socket::Async.connect('localhost', $candidate);
            await Promise.anyof($try-conn, Promise.in(1.0));
            if $try-conn.status == Kept {
                # We could connect, so not free.
                $try-conn.result.close;
            }
            else {
                # Could not connect, so may well be free.
                return $candidate;
            }
        }
        die "Could not find a free port in 100 attempts";
    }

    #| Generates a random secret, which could be used as a password for the
    #| test service instance.
    method generate-secret(--> Str) {
        my constant @chars = flat 'A'..'Z', 'a'..'z', '1'..'9', <_ ->;
        @chars.roll((15..25).pick).join
    }
}

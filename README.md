# Test::ContainerizedService

This module uses containers to provide throw-away instances of services such
as databases, in order to ease testing of code that depends on them. For
example, we might wish to write a bunch of tests against a Postgres database.
Requiring every developer who wants to run the tests to set up a local test
database is tedious and error-prone. Containers provide a greater degree of
repeatability without requiring further work on behalf of the developer
(aside from having a functioning `docker` installation). In the case this
that `docker` is not available or there are problems obtaining the
container, the tests will simply be skipped.

## Usage

### Postgres

```
use Test;
use Test::ContainerizedService;
use DB::Pg;

# Either receive a formed connection string:
test-service 'postgres', -> (:$conninfo, *%) {
    my $pg = DB::Pg.new(:$conninfo);
    # And off you go...
}

# Or get the individual parts:
test-service 'postgres', -> (:$host, :$port, :$user, :$password, :$dbname, *%) {
    # Use them as you wish
}

# Can also specify the tag of the postgres container to use:
test-service 'postgres', :tag<14.4> -> (:$conninfo, *%) {
    my $pg = DB::Pg.new(:$conninfo);
}
```

### Redis

```
use Test;
use Test::ContainerizedService;
use Redis;

test-service 'redis', :tag<7.0>, -> (:$host, :$port) {
    my $conn = Redis.new("$host:$port", :decode_response);
    $conn.set("eggs", "fried");
    is $conn.get("eggs"), "fried", "Hurrah, fried eggs!";
    $conn.quit;
}
```

## The service I want isn't here!

This module is based on `Dev::ContainerizedService`. Please follow [the
instructions](https://github.com/jnthn/raku-dev-containerized-service#the-service-i-want-isnt-here)
to add support for a service to that module; that will mean support is
provided automatically in this one also. Then:

1. Fork this repository.
2. Add an example to the `README.md`.
3. If wanting to be extremely thorough, add a test to this repository also.
4. Submit a pull request.

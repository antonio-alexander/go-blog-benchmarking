# go-blog-benchmarking (github.com/antonio-alexander/go-blog-benchmarking)

Has anyone every told you that when they access a certain endpoint in your API that it's slow? Have you gotten certain reports that your application is slow?...maybe only at certain times a day or when they do a couple of operations in a specific order? My goal is to describe an application's relationship with resources (e.g., CPU and memory), it's environment and how to construct a benchmark.

By reviewing this, you should:

- understand how memory usage can affect CPU usage
- understanding the limitations of networks under load
- understanding the limitations databases under load
- how to characterize the _bandwidth_ of a system
- understanding how benchmarking affects horizontal scaling and whether it can give you more bandwidth
- how to understand the characteristics of a deployment environment
- understand how to architect a benchmark

I think using the term benchmarking is a bit disingenuous, not because I'm a liar or something, but because this is less about benchmarking and more about the reasons, motivations and the _after_ when it comes to benchmarking.

## Bibliography

- [https://dave.cheney.net/2013/06/30/how-to-write-benchmarks-in-go](https://dave.cheney.net/2013/06/30/how-to-write-benchmarks-in-go)
- [https://dave.cheney.net/high-performance-go-workshop/gophercon-2019.html](https://dave.cheney.net/high-performance-go-workshop/gophercon-2019.html)
- [https://en.wikipedia.org/wiki/Priority_inversion](https://en.wikipedia.org/wiki/Priority_inversion)
- [https://reintech.io/blog/fibonacci-number-algorithms-in-go](https://reintech.io/blog/fibonacci-number-algorithms-in-go)
- [https://blog.cloudflare.com/how-to-stop-running-out-of-ephemeral-ports-and-start-to-love-long-lived-connections](https://blog.cloudflare.com/how-to-stop-running-out-of-ephemeral-ports-and-start-to-love-long-lived-connections)

## OSes, Captain Application

<!-- TODO: would be great for a meme here, like Captain Britain -->

Although it is possible to deploy an application to an environment that doesn't contain an operating system...a good majority of application deployments will be deploying to an environment that contains an operating system (a non-real-time operating system). An OS will provide a sandbox to run one or more applications at a given time and will manage __shared__ resources such that it can maintain the sandbox. In short, when resources are limited, the OS will prioritize the sandbox.

> There is a big difference between a real time operating system and a _regular_ operating system. A real time operating system is built to reduce or eliminate jitter and as a result is infinitely more consistent at memory and CPU usage.

All application's running within an OS will be able to use resources at will until one (or both) of the following situations:

- interrupts: interrupts generally occur from hardware (e.g., keyboard, network io, the OS itself, etc.) to which the OS will stop whatever it's doing and handle; this is the biggest contributor of jitter
- limited resources: when there is high CPU usage or high memory usage, the OS will prioritize its critical processes and deny (or destroy) non-OS applications

As you run more applications and the OS must do more "work", the environment can experience something called jitter. Jitter is defined as: slight irregular movement, variation, or unsteadiness, especially in an electrical signal or electronic device. This is the variation in overall resource usage and in some cases the periodicity of resource usage. Some examples of things that _cause_ jitter:

- if a variable were to constantly escape the heap, the effort for the OS to perform memory allocation
- if someone is executing a DoS (denial of service) and the OS is trying to handle incoming requests
- if applications are constantly allocating memory and the memory becomes fragmented enough, the effort to allocate memory will take _longer_ over time
- if your application engages the garbage collector (esp. if done aggressively)

I introduced the ideas of jitter, OSes and shared resources to avoid the pitfall of thinking of an application's resource usage in a vacuum. A statement like: "My tests show that this process generally completes in so many seconds and this kind of CPU has <10% CPU usage on average". This is fair and is very benchmark-esque speak; but saying it without the context of the deployment environment makes it untrue. The exact same application running on a different CPU or OS or OS update may cause your application to no longer be able to maintain that behavior; or even worse if _another_ application causes a CPU spike, your application may no longer be able to maintain that behavior.

## Resources, an application's life blood

Any given application running in __ANY__ environment has a limited set of resources which can include (but is not limited to):

- CPU: the amount of work you can do (cores/instructions per second)
- Memory: the amount of memory (RAM) you must store data
- Disk I/O: how fast you can read/write from disk
- Network I/O: how fast you can read/write from the network (bandwidth)
- Disk Space: how much space you have available (e.g., swap)

Resources for application(s) within a given environment have a practical limit; once that limit is reached, you're at the mercy of that environment (more on this below). As most environments aren't shared by a single application, it's not enough for _your_ application to use resources conservatively, but for __ALL__ applications to properly use shared resources.

<!-- TODO: add a couple of graphs to show how the CPU usage increases with parallelism -->

A common misconception is that you can use parallelism/concurrency to do work faster; it's not that "do work faster" is incorrect, it's the idea that you can do work faster in a vacuum. Yes, you can do work faster, but you're still using those _limited_ resources: you're using more of those _limited_ resources to do work faster.

> There's a reason it's called USB (universal _serial_ bus) and NOT UPB (universal __parallel__ bus). The truth is that serial is always faster (always), but if you understand how resources work, you can take advantage

To boot, not all programming languages, OSes and CPUs have the _same_ concept of concurrency and parallelism, you may think that you can actually execute in parallel, but your CPU, OS or programming language may disagree with you and have adverse effects.

## Application and Environmental Behavior

An application's behavior, especially under load, is the foundation on which you build a benchmark; more specifically: a hypothesis. Understanding how your application uses resources and what it does if there are fewer resources available help you better able to construct hypothesis AND come up with ideas to push the behavior in the direction of the hypothesis you want to prove. In addition (but less so), understanding how an environment reacts to extenuating circumstances help shape behaviors.

> An application's behavior is the combination of an application's behavior within a given environment along with the behavior of other applications within that environment

By this point, you may be having an internal dialogue, thinking that none of these circumstances matter to you because you deploy to the cloud which runs in a container with a single application (yours) and runs the alpine Linux OS, so nothing to worry about. This _too_ is a misconception, there's no guarantee that you're not sharing bare metal with some other pod/container; there's still a __strong__ chance you must account for other applications and resources.

If I were to assign a guiding principle to determining an application's behavior is to _know_ where the lines are so you can color in-between them; like driving, your application's goal is to be a good citizen and drive for everyone else.

An application’s behavior (for purposes of this document) is _what_ happens when any of the aforementioned resources (e.g., database connectivity, disk space, memory, CPU, network io, etc.) become less available. Let’s say for example, you have a process that can be started by one or more users, and it uses 10% of a core every second. This would indicate that you have a "bandwidth" of 10 users per core. If your application exceeds 10 users per core, you may affect the stability of the system.

> You _could_ increase the bandwidth of your application by offsetting those processes: what if the process ONLY took .1s, then if you had ten users, each offset by .1s, then the average CPU usage would probably be around 10%, increasing your bandwidth to something like 100 users per core. A lower average CPU is _better_ than a spike of 100% CPU at any given time. Something like this could be enforced with a queue (an implementation of a producer/consumer design pattern) where you may be producing data ad-hoc but consuming it at a set rate.

Before you can start to develop a benchmark, you must have a good idea of how the application behaves: how it uses resources.

## Benchmarking as a Concept

Benchmarking, like testing, validates a hypothesis and an expected state. It says something along the lines of: I expect this to be the behavior of the application, _all else equal_. Unlike testing, benchmarks are intrinsically attached to the environment it's being run in (e.g., in a workflow, you must always execute the benchmark using the same GitHub runner and OS). Although it may seem obvious, not everything can be benchmarked and the way you construct your benchmarks has a very distinct effect on your ability to create a repeatable benchmark.

"Not everything can be benchmarked" is probably more accurately said as "it doesn't make sense to benchmark everything". If you have access to the source code, it's possible to benchmark using perspectives that aren't exposed (e.g., not from the perspective of the API). Benchmarking something in a way that isn't practically possible is incomplete at best and at worst, simply incorrect. Unlike testing, where being comprehensive and testing things in ways that may not actually match user workflows is valid, with benchmarking, you want to determine the behavior of your application under load and in the way you __expect__ people to use it.

> I'm not _really_ saying that you shouldn't attempt to benchmark possible (even unexpected) use cases, but that it's specifically not a great use of time unless you've already benchmarked everything else. And I’m not saying that there isn't value in benchmarking different perspectives, simply that you want to avoid benchmarking processes that don't match expected/possible behavior

Here are some examples of what I think are "good" benchmarks:

- testing the average time to create an object using an API; at 1000, at 10,000 and at 100,000 users
- testing the average time to update an object using an API; at 1000, at 10,000 and at 100,000 users
- how long it takes to perform a certain operation on average over the course of an extended runtime (an endurance benchmark)
- how long it takes to perform a certain operation on average using load balancing/concurrency

Here are some examples of _bad_ benchmarks:

- a process with growing data (under most circumstances)
- a process that's a subset of a larger process without appropriate reasoning
- a process within different (or inconsistent) environments

I think designing a benchmark can be done with the following steps:

1. determine the perspective you want to benchmark the behavior from
2. determine the behavior you want to benchmark
3. benchmark the behavior and establish a baseline in a known environment
4. use the baseline to validate how changes affect the benchmark

Benchmarks, unlike tests that are centered around verification, are centered around validation. Tests generally verify that an established behavior occurs while benchmarks make a hypothesis about something, and that hypothesis is validated AND _quantified_. More specifically a benchmark will say that a certain operation, when benchmarked, has a statistical likelihood of occurring in each amount of time and if done multiple times, should have very little variation (e.g., +/-10%).

For a given benchmark, you want to ensure that the perspective you execute the benchmark from supports the hypothesis and/or makes it more _honest_. For example, if you're doing a benchmark of an API, it makes sense to test it using the API. If that API __requires__ some kind of authorization token and there's no way to optimize such that the call is negligible, you _must_ include those calls to have a consistent, honest and repeatable result.

> I want to re-iterate the point above that the benchmark has to consider the most common/correct ways to integrate with: the experience of the user/developer MUST be taken into consideration

For a given benchmark, you must focus on a specific behavior, what's the _one_ thing you want to benchmark the behavior of. Not only can a benchmark provide different results for a given perspective, but it will (obviously) provide different results for a given behavior. When determining the behavior, you also must take into account the pre-requisites: can we perform setup once, or do we have to perform setup each time you execute the behavior? This too, like perspectives; if it's not possible to benchmark a behavior without executing the pre-requisites, then you must include them in the benchmark.

> In the same vein, you may find that a given behavior doesn't happen often (or never happens on its own); it may not make sense to benchmark it. Alternatively, you may determine that no-one uses a given API with any regularity or there are no non-functional requirements to its speed...so you don't need to benchmark it

Perspective, behavior and environment can be thought of as "controls" to the experiment, you want to make these things _static_ for the purposes of testing such that the variable is only the hypothesis. The environment is the thing that houses the _resources_ the benchmark uses as well as any additional dependencies such as a database, a service, a hard drive and/or a browser. Control could be the version of operating system or browser, or the type of hard drive (e.g., spinny vs ssd) or the kind of database, or the network uplink (e.g., the connection between the database and the operating system).

> Although "control" is used, it's application is loose for a given environment. The practical limit for control is that you simply want to make sure that the environment is consistent enough to provide repeatable outcomes, but as an extension, you may modify the environment slightly to understand how it changes the results of the benchmark

## How to Benchmark

Benchmarking in practice is easy enough. You execute the following steps:

   1. record the current time
   2. attempt to execute the process being benchmarked a known number of times
   3. and once complete, record the current time
   4. divide the different in start time and finish time by the number of times the process was executed

The resulting duration provides an idea of _how long_ it takes to execute the process on average; in general, it's important to note that the number of times you perform the process for benchmarking has a statistically effect on how repeatable the results are, for some benchmarks you may find more iterations are required to get a repeatable result.

Go provides some simple (as per usual) tools for benchmarking almost identical to integration for testing. the Benchmarking function looks like the following:

```go
package internal_test

import (
    "testing"

    "github.com/antonio-alexander/go-blog-benchmarking/internal"

    "github.com/stretchr/testify/assert"
)

func BenchmarkFibonacci(b *testing.B) {
    const n int = 10

    for i := 0; i < b.N; i++ {
        internal.Fibonacci(n)
    }
}
```

> Something to keep in mind about this benchmark is to understand that the constant _n_ at the top of the Benchmark is what makes this behavior consistent; if n were to keep changing, this benchmark would be all over the place

You can execute the benchmark with the following command (this command will omit any tests):

```sh
go test -bench=. -run=^a -benchtime=1s -parallel=1 -count=27
```

The result of said benchmark is:

```log
goos: linux
goarch: amd64
pkg: github.com/antonio-alexander/go-blog-benchmarking/internal
cpu: Intel(R) Celeron(R) N4020 CPU @ 1.10GHz
BenchmarkFibonacci-2    74162642                16.69 ns/op
BenchmarkFibonacci-2    73919964                16.02 ns/op
BenchmarkFibonacci-2    65530470                15.72 ns/op
BenchmarkFibonacci-2    69973798                15.85 ns/op
BenchmarkFibonacci-2    73050229                15.80 ns/op
BenchmarkFibonacci-2    72476516                15.71 ns/op
BenchmarkFibonacci-2    69943022                15.87 ns/op
BenchmarkFibonacci-2    69670813                16.00 ns/op
BenchmarkFibonacci-2    67752715                15.99 ns/op
BenchmarkFibonacci-2    74198534                15.70 ns/op
BenchmarkFibonacci-2    71981228                15.62 ns/op
BenchmarkFibonacci-2    68121990                16.09 ns/op
BenchmarkFibonacci-2    70387790                16.13 ns/op
BenchmarkFibonacci-2    73110486                15.94 ns/op
BenchmarkFibonacci-2    75142644                16.03 ns/op
BenchmarkFibonacci-2    75985102                16.06 ns/op
BenchmarkFibonacci-2    71578314                16.06 ns/op
BenchmarkFibonacci-2    62771613                16.01 ns/op
BenchmarkFibonacci-2    66195825                16.25 ns/op
BenchmarkFibonacci-2    70285984                15.98 ns/op
BenchmarkFibonacci-2    69993177                15.93 ns/op
BenchmarkFibonacci-2    72434421                15.99 ns/op
BenchmarkFibonacci-2    63376292                16.18 ns/op
BenchmarkFibonacci-2    66035691                15.68 ns/op
BenchmarkFibonacci-2    66567156                15.95 ns/op
BenchmarkFibonacci-2    72529744                15.98 ns/op
BenchmarkFibonacci-2    76529524                16.86 ns/op
PASS
ok      github.com/antonio-alexander/go-blog-benchmarking/internal      33.375s
```

As you can see above, the ns/op will vary over time; this is due to general [unavoidable] jitter. The important configuration parameters we provide are benchtime and count: benchtime provides a minimum amount of time for the benchmark to run to make the ns/op more consistent while count provides you more data for benchstat (more on this later).

Once you perform a benchmark, you can output the log to a file for comparison purposes (the one that's above). The nice people at Google have created a utility called [benchstat](https://pkg.go.dev/golang.org/x/perf/cmd/benchstat) that can be used to compare different runs between benchmarks. What you can do is store an old log (some call it a "golden" log) and use benchstat to compare it with another log. If you do it, you'll get an output like this:

```sh
benchstat ./benchmarks/go-blog-bencmarking_benchmark-golden.log ./tmp/go-blog-benchmarking_benchmark.log 
```

```log
goos: linux
goarch: amd64
pkg: github.com/antonio-alexander/go-blog-benchmarking/internal
cpu: Intel(R) Celeron(R) N4020 CPU @ 1.10GHz
            │ ./benchmarks/go-blog-benchmarking_benchmark-golden.log │ ./tmp/go-blog-benchmarking_benchmark.log │
            │                         sec/op                         │         sec/op          vs base          │
Fibonacci-2                                              15.99n ± 1%              16.09n ± 1%  ~ (p=0.166 n=27)
```

This output shows that in comparing the benchmarks, the variation is ~1% (which is really good). In practice you'd create an alternate golden benchmark file for each individual environment.

<!-- TODO: mention executing a benchmark in docker vs in the OS, -->

## Benchmarking Environment

The benchmarking environment (or deployment environment); is the final and to some degree the most important lever (outside of the code itself) that can affect the consistency and success of benchmarking. In a way, like he who controls the spice, because the environment controls the resources, it has the biggest sway on benchmarking, only second to perspective itself. The environment itself is a kind of black hole of knowledge; you're at the mercy of what you don't know. In no way will this be a comprehensive guide about environments, but I'll provide two anecdotes to show how environments have incredible sway on the results of your benchmarks.

A "resource service", is a service that doesn't have a lot of logic on its own, it will provide an API to access data stored in a database and as a rule is generally stateless (i.e., if you restart the process, it can pick up right where it started, and no one process is _functionally_ unique). Within this kind of service, most of the work is done by the environment rather than the service itself, so in trying to optimize (or even benchmark) a resource service, you must understand how it uses the environment.

An offshoot of benchmarking is load testing; through load testing, you can optimize a given behavior (i.e., increase the performance of a benchmark by reducing its time to completion). A successful load test can reveal how your service uses resources and the limits of that; especially in regard to a given environment. The general flow of behavior with an API is to make the request via REST/TCP, that request being routed through the service itself, and then a query being made to the database to retrive the data and finally returning that to the entity using the API.

Your gut may tell you that rate at which you can execute requests (e.g., load testing) is limited by network bandwidth (e.g., on a gigabit line, you can execute more requests), but the truth is that you're limited by the OS's network stack. Each time you make a TCP request an [ephemeral port](https://en.wikipedia.org/wiki/Ephemeral_port) is allocated, used and once completed is returned to a pool of ports. The number of ephemeral ports is _relatively fixed_, meaning that you can only handle a fixed set of API calls concurrently on the order of 20,000 requests; this is high, but in general it means that the environment (or each pod in kubernetes) is limited to this fixed number of requests.

But let’s say, that you load it up, you make 20,000 requests at the exact same time, but you have this itch that there's still room for improvement. You then set your eyes on the database, you notice that it's CPU and memory usage is higher than the service itself, so you optimize the query, you do your due diligence with EXPLAINs and indexes. You find...that it’s still slow; on further investigation, you realize that you're receiving responses in sets of 50. You do some research and find that the maximum number of database connections is 50 and by increasing that number, you find that you can process more data concurrently (e.g., chunks of 100 if the maximum number of connections is set to 100).

> Using the above, we can "calculate" that from the perspective of the ephemeral ports, we can handle 20,000, concurrent connections, but from the perspective of the database, we can only handle 50 concurrent connections. As a result, the "bandwidth" of your application is 50 requests concurrently for the amount of time it takes to do the database transaction, BUT you can queue up to 20,000 requests at a given time. So if it takes 1s to perform the database call and the total round-trip time is 1s, the fastest you can complete a request is 2s, and the slowest is situational dependent on how long it takes for the queued request to get access to a database connection

By following behavior from start to finish and trying to optimize it along the way, you'll find that the environment plays a significantly larger part in how the service uses resources and the limits of the benchmark. Optimizing a behavior involves the lowest common denominator, the most limiting factor of the entire chain.

## High Availability (Load Balancing/Kubernetes)

I think this deserves it's own section, but it's closely related to the deployment environment. One of the _easiest_ solutions to situations where you want to add "bandwidth" to an application without changing the application itself, is to use a load balancer or an orchestration tool like Kubernetes (I think others exist, but they clearly don't matter). Load balacing or K8s can create one or more instances of your application and load balance requests across the two instances.

I think it goes without saying that adding K8s or load balancing to an application without understanding how the application uses resources. Determining how to implement a load balancer is a kind of art in itself. A load balancer has to have a kind of trigger that tells it when to _enable_ the load balancer; for example:

- with http/https requests you can round robin to different hosts
- with kafka, you can load balance using a consumer group and partitions
- you can horizontally scale (create more instances of an application) when an instance reaches a certain threshold for CPU/memory

For example, if your application uses Kafka as a technology (as opposed to http); there aren't active connections being made, so you can't round-robin to distribute the load. If you set CPU limits, once it's breached, it'll scale horizontally, but the new instance won't necessarily get any data (unless you use a consumer group). In addition, consumer groups are practically static, creating new partitions is something you have to plan or manually do (it may involve downtime).

Alternatively, if you use CPU/memory as triggers, you can set them too high. If the lowest common denominator for your application is port number, you may reach the maximum bandwidth with a low CPU usage; hence __just__ applying kubernetes or load balancing to the problem doesn't necessarily solve it.

## Life After Benchmarking?

Earlier, I mentioned that benchmarks are more of a hypothesis and associated more with validation rather than verification. Once you create a benchmark for a behavior, from a specific behavior within a specific environment, you may then attempt make that hypothesis true or rather _more_ true since benchmarks are quantitative. Once you establish a benchmark the next steps often revolve around:

- changing the controls (e.g., the environment) to determine if the benchmark is repeatable
- developing a sort of heat map to understand where time is being spent
- establishing new benchmarks to test different hypotheses
- regression testing to ensure that code changes don't adversely affect benchmarks in established environments
- changing code to optimize a behavior

In a way, benchmarks (again, unlike tests) are a means to an end rather than an end in itself. The result of a benchmark inform decisions. For example, let’s say that I did go through the trouble mentioned in the section above and optimized API calls such that I used all the ephemeral ports and maxed out the database connections. But I do a little more research and find that my benchmark was flawed, I was making requests from the same IP address and in practice, it'd be from different addresses; but then I thought...practically it makes more sense to limit the usage of my API than to allow it to fail in practice if I know what these limits are.

So, the result of the benchmarking could be a decision to implement rate limiting: we identify the unique users of our API and ensure that they can only use a subset of the bandwidth we have (e.g., if we had 10 unique users, we'd limit each one to 2,000 concurrent requests, preserving our "bandwidth"). Alternatively, you could do some auditing and determine that you're daily peak requests come nowhere near the practical bandwidth of the application and as a result you do nothing, but set an alarm to let you know if this trends upward so you can implement a solution.

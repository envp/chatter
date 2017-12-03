# COP5615 - Project 4 Part 1

### Running the code

The project builds into a single binary called `backend` that can be run
in multiple modes by specifying CLI flags. Below is the CLI
documentation along with examples on how to run the binary.

A `--help` flag is provided with in the binary for additional documentation.

1.  To build the binary run: `mix escript.build`

2.  Start the local EPMD daemon by running `epmd -daemon`, this step is
    necessary as the code will not function without EPMD running.

3.  To run the application in server mode, execute:

                ./backend --mode=server --address=127.0.0.1
                

4.  To run the simulator, ensure that the `backend` server process is
    running locally and execute the below code (formatted multiline).
    The `–-size` and `-–nchar` parameters control the number of users
    simulated and the number of characters per tweet respectively.

                ./backend --mode=simulator --address=127.0.0.1 \
                --size=<NUMBER_OF_USERS_TO_SIMULATE> \
                --nchar=<NUMBER_OF_CHARACTERS_PER_TWEET>
                

Once run, the simulator displays the average number of tweets registered
by the API per second, in the background each simulated user is created
as a separate process that sends a tweet with 0 to 2 mentions and
hashtags to the server every 100ms.

### Architecture

This project is part of a mix umbrella project, and the various components are split as follows:

	├── lib								
	│   ├── simulator				
	│   │   ├── user_process.ex (Simulates an individual user making tweets and requests on the client side)
	│   │   └── zipf.ex			(Helper functions to generate powerlaw/zipf distributions)
	│   ├── twitter_backend
	│   │   ├── application.ex
	│   │   ├── cli.ex			(Command line interface and entry point for main/1 )
	│   │   ├── core_api.ex		(Globally named GenServer that exposes functionality to the world)
	│   │   ├── database.ex		(Wrapper around all of the ETS tables used and operations performed on them)
	│   │   ├── feed.ex			(A key-value based Queue to model the live-feed of all the users)
	│   │   ├── simulator.ex	(Simulator that creates a process for each simulated user and initiates the stress-test)
	│   │   │
	│   │   ├── tweet.ex		(Record to represent the fields of a tweet, along with providing functions to parse tweets)
	│   │   └── user.ex			(Record to represent the fields of a single user)
	│   └── twitter_backend.ex

The server contains:
* A database-like wrapper around ETS tables that store all the key information
* A globally named API server that bridges the database and clients
* A queue to store unread notifications that are regularly flushed when sent to users

The simulator:
* Creates a distinct process for each simulated user that tweets every 100ms on average.
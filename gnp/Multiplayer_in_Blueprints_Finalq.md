# Multiplayer in Blueprints
**Assignment 3 - Game Network Programming**

**DEPARTAMENTO DE ENGENHARIA INFORMÁTICA**  
**UNDERGRADUATE IN GAMES AND MULTIMEDIA**  
**Academic Year 2025/2026 - 2º Semestre**

---

## Executive Summary

This comprehensive guide covers **multiplayer game development in Unreal Engine 5 using Blueprints**. You will learn fundamental concepts of networked multiplayer games, including client-server architecture, replication systems, and best practices for creating responsive and synchronized gameplay experiences.

### What You'll Learn

**Core Concepts:**
- Client-Server Architecture
- Replication Systems
- Network Modes
- Actor & Variable Replication
- Remote Procedure Calls (RPCs)
- Network Authority

**Practical Skills:**
- Blueprint Networking
- RPC Implementation
- RepNotify Variables
- Performance Optimization
- Debugging Multiplayer

### Prerequisites

- Basic understanding of Unreal Engine 5
- Familiarity with Blueprint visual scripting
- Understanding of game development concepts
- Access to UE5 and ContentExamples project

### Time Estimate

**Estimated completion time:** 8-12 hours (including exercises)

---

## Table of Contents

1. [Networking Overview](#networking-overview)
2. [Plan Early for Multiplayer](#plan-early-for-multiplayer)
3. [Unreal Engine Networking Architecture](#unreal-engine-networking-architecture)
4. [Client-Server Gameplay Example](#client-server-gameplay-example)
5. [Network Modes](#network-modes)
6. [Server Types](#server-types)
7. [Replication](#replication)
8. [Actor Replication](#actor-replication)
9. [Debugging, Profiling, and Testing](#debugging-profiling-and-testing)
10. [Networking Tips](#networking-tips)
11. [Multiplayer in Blueprints](#multiplayer-in-blueprints)
12. [Hands-On Tutorial](#hands-on-tutorial)
13. [Exercises](#exercises)

---

# Networking Overview

> **Key Concept:** The UE5 framework is built with multiplayer gaming in mind. If you follow the basic framework conventions, you generally don't have to do much to extend a single-player experience to multiplayer.

UE5 networking is built around the **server/client model**. This means there will be one server that is authoritative (makes all the important decisions), and this server will make sure all connected clients are continually updated so they maintain the most up-to-date approximation of the server's world.

> **Important:** Even non-networked, single-player games have a server; the local machine acts as the server in these cases.

## Understanding Network Communication

In multiplayer game sessions, game state information is communicated between multiple machines over a network connection. In contrast, single-player local games store all game state information on a single machine.

### Single-Player vs Multiplayer

**Single-Player:**
- All data on one machine
- Instant communication
- No network latency
- Simple architecture

**Multiplayer:**
- Data across multiple machines
- Network delays
- Synchronization challenges
- Complex architecture

Communication over a network connection makes creating multiplayer experiences inherently more complex than single-player experiences. The process of sharing information between players involves a different approach than a single-player game. Unreal Engine features a robust networking framework that powers some of the world's most popular online multiplayer games to help you streamline this process.

---

# Plan Early for Multiplayer

> **Critical Planning Advice:** If there is any possibility that your project might need multiplayer features at any time, you should build all your gameplay with multiplayer in mind from the start of your project.

## Benefits of Early Planning

If your team consistently implements the extra steps for creating multiplayer, the process of building gameplay will not consume much more time compared to a single-player game.

**Advantages:**
- Easier debugging and maintenance
- Streamlined service updates
- Single-player functionality preserved
- Future-proof architecture

## Cost of Refactoring

If you do not design your project with multiplayer in mind from the beginning, refactoring a codebase that you have already built without networking will require you to:

1. Comb through your entire project
2. Rewrite large sections of gameplay functionality
3. Reconsider your design due to technical obstacles (network speed, stability)
4. Potentially change your existing design

Meanwhile, any gameplay programmed for multiplayer in UE will still work as expected in single-player, non-networked play.

---

# Unreal Engine Networking Architecture

UE uses the client-server architecture for networked multiplayer games. There are two types of multiplayer games: **local multiplayer** and **networked multiplayer**.

## Local Multiplayer

In a single-player or local multiplayer game, your game runs locally on a single machine as a standalone game. In this instance, all players, assets, and functionality exist and all input is processed on a single machine. Players connect input to this machine and control everything directly in the game. There is no potential issue with communicating input from a player to the game because the player is connected directly to the game instance.

*[Image: Figure 1 - Single-player and local multiplayer take place on only one machine]*

## Networked Multiplayer

In a networked multiplayer game, many players on distinct machines connect to a central machine across a network. The central machine, known as the **server**, hosts the multiplayer game while all other players on different machines connect to the server as **clients**. The server shares game state information with each connected client and provides the means for all players on different machines to communicate with one another.

*[Image: Figure 2 - In networked multiplayer, the game takes place between a server and several connected clients]*

As opposed to local multiplayer, this presents additional challenges:
- Different clients might have different network connection speeds
- Information must be communicated across a potentially unstable network where input might get lost
- At any given time, the state of the game on one client machine is likely different from every other client machine

The server, as the host of the game, holds the one true **authoritative game state**. In other words, the server is where the multiplayer game is actually played. The clients each control remote Pawns that they own on the server. Clients send remote procedure calls from their local pawn to their server pawn to perform in-game actions. The server then replicates information about the game state to each client, such as where Actors are located, how these actors should behave, and what values different variables should have.

---

# Client-Server Gameplay Example

This section provides a side-by-side comparison of two players in a multiplayer game to illustrate the differences between local and networked multiplayer.

*[Image: Comparison of local multiplayer (left) vs networked multiplayer (right)]*

## Local Multiplayer vs Networked Multiplayer

### Player 1 Fires a Weapon

**Local Multiplayer:**
- Player 1's Pawn responds by firing its current weapon
- Player 1's weapon spawns a projectile and plays any accompanying sound or visual effects

**Networked Multiplayer:**
- Player 1's local Pawn relays the command to fire the weapon to its connected Pawn on the server
- Player 1's weapon on the server spawns a projectile
- The server notifies each connected client to create its own copy of Player 1's projectile
- Player 1's weapon on the server notifies each client to play the sound and visual effects associated with firing the weapon

### Projectile Movement

**Local Multiplayer:**
- Player 1's projectile moves forward from the weapon

**Networked Multiplayer:**
- Player 1's projectile on the server moves forward from the weapon
- The server notifies each client to replicate the movement of Player 1's projectile as it happens, so each client's version also moves

### Projectile Collision

**Local Multiplayer:**
- The collision triggers a function that destroys Player 1's projectile, causes damage to Player 2's pawn, and plays accompanying sound and visual effects
- Player 2 plays an on-screen effect in response to being damaged

**Networked Multiplayer:**
- The collision triggers a function that destroys Player 1's projectile on the server
- The server automatically notifies each client to destroy their copy of Player 1's projectile
- The collision triggers a function that notifies all clients to play accompanying sound and visual effects
- Player 2's pawn on the server takes damage from the projectile collision
- Player 2's pawn on the server notifies Player 2's client to play an on-screen effect in response to being damaged

## Understanding Multiple Worlds

In the local multiplayer game, these interactions all take place in the same world on the same machine, making them simpler to understand and program.

In the networked multiplayer game, these interactions take place in several different worlds:
- **Authoritative world on the server**
- **Player 1's client world**
- **Player 2's client world**
- **Additional worlds** for any other clients connected to this server

Each world has its own player controllers, pawns, weapons, and projectiles. The server is where the game is actually played, but each client's world must accurately replicate the events happening on the server. Therefore, it is necessary to selectively send information to each client to create an accurate visual representation of the world on the server.

This process introduces a division between:
- **Essential gameplay interactions** (collisions, movement, damage)
- **Cosmetic effects** (visual effects and sounds)
- **Player information** (HUD updates)

Each of these is relevant to a specific machine or set of machines in the network. The primary challenges involve choosing what information you should replicate to which connections to provide a consistent experience for all players while minimizing the amount of information replicated so network bandwidth is not constantly saturated.

---

# Network Modes

UE5 supports four different network modes, each suited for specific use cases:

| Network Mode | Description | Best Use Case |
|--------------|-------------|---------------|
| **NM_Standalone** | Server running on local machine, not accepting remote clients | Single-player or local multiplayer games |
| **NM_DedicatedServer** | Server with no local players; optimized performance by discarding graphics/sound | Competitive MOBAs, MMOs, online shooters requiring high-performance servers |
| **NM_ListenServer** | Server hosting a local player while accepting remote connections | Casual cooperative/competitive multiplayer, user-hosted games |
| **NM_Client** | Not a server; connects to dedicated or listen server | Player connection to any multiplayer game |

## Detailed Descriptions

### Standalone (NM_Standalone)
Indicates a server running on a local machine and not accepting clients from remote machines. Best for single-player games and local multiplayer. This is the simplest configuration.

### Dedicated Server (NM_DedicatedServer)
Has no local players and can run more efficiently by discarding sound, graphics, user input, and other player-oriented features.

**Advantages:**
- Maximum performance
- Enhanced security
- Fair gameplay (no host advantage)
- Better scalability

**Used by:** Competitive MOBAs, MMO games, online shooters

### Listen Server (NM_ListenServer)
A server that hosts a local player but is open to connections from remote players.

**Advantages:**
- Easy to set up
- No hosting costs
- Community-driven servers

**Disadvantages:**
- Host has latency advantage
- Higher processing load on host
- Can be terminated by host without warning

### Client (NM_Client)
The only mode that is not a server. The local machine connects as a client to a dedicated or listen server and will not run server-side logic.

---

# Server Types

## Listen Server

Listen servers are designed to be simple for users to set up spontaneously since any user with a copy of the game can both start a listen server and play on the same machine. Games that support listen servers often feature an in-game user interface for starting a server or searching for existing servers to join.

Listen servers are not without disadvantages. Because the player hosting the listen server is playing on the server directly, they have an advantage over the players who are playing as clients. This might raise concerns about fairness. Additionally, there is an additional processing load associated with running as a server while also supporting player-relevant systems like graphics and audio rendering.

These factors make listen servers less suitable for games in highly competitive settings or games with very high network loads, but convenient for casual cooperative and competitive multiplayer among small groups of players.

## Dedicated Server

Dedicated servers are more expensive and challenging to configure. They require a separate machine from all other players participating in the game, complete with its own network connection. All players joining a dedicated server experience the game with a remote network connection that ensures a better chance of fairness.

Since a dedicated server does not render graphics or perform logic only relevant to local players, it is able to process gameplay events and perform networking functions more efficiently. This makes dedicated servers preferable for games that require:
- Large numbers of players
- High-performance, trusted servers for security
- Fairness and reliability

Such games include Massively Multiplayer Online games (MMOs), competitive Multiplayer Online Battle Arena games (MOBAs), and fast-paced online shooters.

---

# Replication

**Replication** is the process of the authoritative server sending state data to connected clients. As previously mentioned, the true game state exists on the server. Connected clients replicate this state locally and render graphics and audio so a client can communicate with other clients and participate in the game. If replication is configured correctly, different machines' game instances synchronize and gameplay runs smoothly.

Actors and actor-derived classes are the primary classes designed for replicating their state over a network connection in UE. **AActor** is the base class for an object that can be placed or spawned in a level and is also the first class in UE's UObject inheritance hierarchy that is supported for networking.

Within the context of UE, there are two different areas relevant when talking about replication:

1. **The objects being replicated** - Flagging properties requiring replication and defining functions that are called over a network connection
2. **The internal system** - Responsible for the act of replicating objects to the correct machines

---

# Actor Replication

Actors interact over a network using several mechanisms:
- **Replicated Properties** - Actor properties that replicate their state over the network
- **Replicated Using Properties (RepNotify)** - Actor properties that replicate and call a function when their state is replicated
- **Remote Procedure Calls (RPCs)** - Allow actors to call a function from one machine and run it on a different machine

## Actor Replication Process

Actor replication is a highly detailed, multi-step process that involves:

1. Client machine determines what actors need to replicate to which connections
2. Server determines the order in which property updates and remote procedure calls are performed
3. Server sends relevant information to all other connected clients

By default, most actors do not replicate. You can enable replication for actor-derived classes by setting the `bReplicates` variable in C++ or the **Replicates** setting in Blueprint to **true**.

## Replication Features Overview

| Feature | Description |
|---------|-------------|
| **Creation and Destruction** | When an authoritative version of a replicated actor is spawned on a server, it automatically generates remote proxies on all connected clients. If you destroy an authoritative actor, it automatically destroys its remote proxies. |
| **Movement** | If an authoritative actor has Replicate Movement enabled, it automatically replicates its Location, Rotation, and Velocity. |
| **Properties** | Any properties designated as being replicated automatically replicate from the authoritative actor to its remote proxies whenever their values change. |
| **Components** | Actor components replicate as part of the actor that owns them if they are set to replicate. |
| **Subobjects** | Any UObject-derived can be attached to an actor and replicated as a subobject. |
| **Remote Procedure Calls** | RPCs are special functions transmitted to specific machines in a network game. They may be designated as Server, Client, or NetMulticast. |

## Non-Replicated Features

Common use cases such as creation, destruction, and movement are handled automatically, but all other gameplay features do not replicate by default, even when you enable replication for an actor. You must manually designate:

- Properties to replicate and any custom conditions
- Functions to replicate and manually call them in your code
- Components and subobjects to replicate and any of their associated properties and functions

Several common features of actors, pawns, and characters do not replicate:
- Skeletal Mesh Component
- Static Mesh Component
- Materials
- Animation Blueprints
- Particle System Component
- Sound Emitters
- Physics Objects

Each of these runs separately on all clients. However, if the variables that drive these visual elements are replicated, it ensures that all clients have the same information and each simulates these features in approximately the same manner.

---

# Debugging, Profiling, and Testing

The added complexity of multiple game instances, varying reliability of network connections, and differing functionality between a server and clients makes debugging, profiling, and testing networked multiplayer games an essential part of the development process. UE provides several features and specialized tools to help you debug, profile, and test your project.

---

# Networking Tips

Follow these best practices to optimize your networked multiplayer game:

## RPC Best Practices

- **Minimize RPC Usage** - Use as few RPCs as possible. If you can use a RepNotify property instead, you should
- **Prefer RepNotify over RPCs** - Variables are more reliable for persistent state
- **Use multicast functions sparingly** - They create extra network traffic for each connected client
- **Server-only logic placement** - Doesn't necessarily have to be in a server RPC if you can guarantee non-replicated function only executes on server

## Reliability Guidelines

> **Caution with player input:** Players can rapidly press buttons and overflow the reliable RPC queue. Implement rate limiting mechanisms.

- **Make RPCs unreliable if called often** - Especially inside actor tick functions
- **Avoid reliable RPCs in loops** - Can quickly saturate bandwidth

## Optimization Strategies

- **Recycle functions when possible** - Call them in response to gameplay logic and use them as RepNotifies
- **Check your actor's network role** - Useful for filtering execution in functions
- **Check if your pawn is locally controlled** - Use `IsLocallyControlled` for filtering based on pawn ownership

## Critical Optimizations

> **Make use of network dormancy** - It is one of the most significant optimizations you can make in your network gameplay.

---

# Multiplayer in Blueprints

UE5 provides extensive multiplayer functionality out of the box, making it easy to set up a basic Blueprint game that works over a network. Most of the logic to make basic multiplayer work comes from built-in networking support in the Character class and its CharacterMovementComponent, which the Third Person template project uses.

## Gameplay Framework Review

To add multiplayer functionality to your game, it's important to understand the roles of major gameplay classes and how they work in a multiplayer context:

### GameInstance
- Exists for the duration of the engine's session
- Created when engine starts up, destroyed when engine shuts down
- Separate GameInstance exists on server and each client (these do not communicate with each other)
- Exists outside game session and across level loads
- **Good for:** Persistent data like lifetime player statistics, account information, or map rotation lists

### GameMode
- **Only exists on the server**
- Stores information related to the game that clients do not need to know explicitly
- **Example:** If a game has special rules like "rocket launchers only", clients may not need to know this rule, but the server needs to know when randomly spawning weapons

### GameState
- Exists on server and clients
- Server uses replicated variables to keep all clients up-to-date
- **Ideal for:** Information of interest to all players and spectators that isn't associated with a specific player
- **Example:** Team scores and current inning in a baseball game

### PlayerController
- One PlayerController exists on each client per player on that machine
- Replicated between server and associated client, but not to other clients
- Server has PlayerControllers for every player
- Local clients have only PlayerControllers for their local players
- Persist while client is connected, associated with Pawns but not destroyed and respawned like Pawns
- **Well-suited for:** Communicating information between clients and servers without replicating to other clients

### PlayerState
- Exists for every player connected to the game on both server and clients
- Used for replicated properties that all clients are interested in
- **Example:** Individual player's current score in a free-for-all game
- Like PlayerController, associated with individual Pawns but not destroyed and respawned when Pawn is

### Pawns (including Characters)
- Exist on server and all clients
- Can contain replicated variables and events
- The PlayerController and PlayerState persist as long as owning player stays connected
- Pawns may be destroyed and replaced (e.g., when a Pawn dies)
- **Example:** Pawn's health would be stored on the Pawn itself since it's specific to that instance

---

# Hands-On Tutorial

For this hands-on section, we will use the **ContentExamples** project. Open this project and then open the **Network_Features** map.

## Understanding Client-Server Model

The first fundamental concept to understand with Unreal's networking is that games run on what is called a **client-server model**. This means there's a server machine serving as the host of the game, allowing potentially multiple clients to connect to it and communicate data back and forth.

The key point to notice is that communication between client and server happens such that the client sends data to the server, and then the server sends that data out to other clients. The clients, for gameplay purposes, usually don't communicate directly with each other.

**Example:** If you are a client playing a shooter and press W to move forward, you tell the server that you moved forward, and the server broadcasts the necessary information for all other clients to know how you moved.

### Server Authority

An important thing to keep in mind throughout this process is that **the server is basically the "king"**. You want to always make sure that things very important from a gameplay perspective—the rules, who wins, who loses, health modifications, anything that helps determine how gameplay functions—happens **exclusively on the server**. Then if clients need to know about it, we make sure to tell them for purposes of displaying UI or updating visual information.

Using our shooter example: if two players are shooting at each other and one takes damage, you want the server to be the one that determines and actually subtracts the damage, so that client machines can't cheat.

## Server Types: Listen vs Dedicated

When we talk about servers in UE5, we focus on two different types:

### Listen Server
The machine hosting the game and acting as the authority is also running a client at the same time. If you're hosting a game on your own computer and invite friends to join, you would be the listen server. Your machine operates as the server for the whole game, but you yourself are also playing—you have a monitor, visuals rendering, and you're entering input directly.

### Dedicated Server
Exclusively devoted to acting as the server for other clients to join. Historically does not have input or rendering. There is no local player playing on the server. Dedicated servers traditionally have optimizations making them more efficient since they're not rendering anything. Some games even make the executable for the dedicated server a separate executable containing only special logic to help prevent cheating.

For this assignment, we'll mostly look at listen servers, but the general concepts apply to both cases.

## Replication Explained

**Replication** is a term you'll hear frequently throughout this assignment. The simple explanation is that it means data and commands being communicated between machines back and forth.

Consider our shooter example: If we have a character with full health who is happy, how do we handle when he takes damage and send it to other clients that he's now sad and has lost health? We call this **replicating the health value**. The server handles the change, makes sure the change is legitimate, decrements his health, and then replicates that value to clients so they can see the value and display a health bar if needed.

Whenever we say replication or talk about it, we're meaning the transmission of different data and commands between these machines and how they communicate. We can replicate:
- **Variables** (like health)
- **The existence or non-existence of actors** (whether an actor spawns on clients)
- **Blueprint function calls** (which we'll cover later)

## Testing Multiplayer in Editor

You can play your game in a multiplayer way. When you're in the editor and press on the side of the **Play** button, a drop-down appears allowing you to test multiplayer quickly.

### Setting Up Multiplayer Testing

1. Set the **Number of Players** to 2 or more
2. When you press **Play**, you'll get one or more windows running the game—one for each player
3. Go to **Advanced Settings** and change the default window size so we can have multiple windows easily on screen
4. Select the **New Editor Window** play mode and play the game

You'll see we have two windows. At the top, one says **Server** and the other says **Client**. The HUD rendering "Server" and "Client" is special to this test map and won't happen by default in your own levels.

### Emulating a Dedicated Server

If you want to emulate a dedicated server, there's a checkbox that says **'Launch Separate Server'**. You can change the number down to 1 client. When you play it, the window that pops up—even though there's only one—says it is a **client** because it's connected to a dedicated server emulation in the background. This is the equivalent of being a client connected to a dedicated server that's not rendering anything and not handling a player locally.

---

## Practical Examples

### 1. Actor Replication

**Actor replication** means that if an Actor replicates, when it's spawned on the server, it will be sent to all clients (all remote machines), and they'll be aware of that Actor's existence. However, if an Actor does not replicate, remote machines won't know about it when it spawns.

#### Enabling Replication

To enable replication for any Actor that you want to display for every machine in the game, you must check the **Replicates** checkbox in the Actor's details panel under the Replication section.

*[Replication settings in Blueprint details panel]*

Anytime you want to spawn an Actor that will handle networking correctly and be networked to all machines that connect to the game, make sure to check this checkbox. This ensures the Actor replicates to all machines that join.

There are more complex scenarios where sometimes things only replicate to the person who owns them, but for most cases, 99% of the time what you want is replication to everybody, which requires just that checkbox.

---

### 2. Detecting Network Authority

Basically, you want to make sure that anything that is a gameplay-important Actor (like ghosts or enemies) only gets spawned on the server. You can use the **Switch Has Authority** node to determine this.

*[Switch Has Authority node in Blueprint]*

#### What is Authority?

This node checks: **Is the Blueprint script executing right now executing on a machine that is the network authority, or is it a remote machine?** Most use cases when you say "Authority" mean the server. This is basically asking, "Am I the server, or am I a client?"

The reason it doesn't just say "server" or "client" is because there are scenarios where the server is not actually the authority over an Actor. A very good example: If you're making UI and add an Actor that is your HUD, it's probably only spawned on the client, and the server completely doesn't care that it exists. In that case, the client has authority over the HUD because they own it, they spawned it, and nobody else knows about it.

But for almost every other scenario, **the authority is going to be the server**.

#### Using Switch Has Authority

You can use Switch Has Authority to gate functionality:
- **Authority branch:** "I only want gameplay or things to happen on the server"
- **Remote branch:** "I only want them to happen on clients," or vice versa

**Most common use case:** When doing something very gameplay-important. Going back to the shooter example: when a player is taking damage or we're doing something that directly impacts how the game functions, that will usually be wrapped with this node first, making sure it's only the authority who executes the code.

---

### 3. Variable Replication

We move from the concept of Actor replication to **variable replication**. We've decided to replicate the Actor (the ghost). We want the ghost Actor available to all client machines. However, it doesn't always make sense to replicate every single piece of information that's possibly on the ghost. There's a lot of information that maybe only the server needs to know about, or that other people don't care about. So you want to be able to set whether certain variables on an Actor are replicated or not.

#### Setting Up Variable Replication

In the details panel of variables on your actors, there's a **Replication** drop-down that lets you control how your variables are replicated:

| Option | Description |
|--------|-------------|
| **None** | Default for new variables; the value will not be sent over the network to clients |
| **Replicated** | When the server replicates this actor, it sends this variable to clients. The value updates automatically on receiving clients. Updates may be delayed by network latency. Remember: replicated variables only go in one direction, from server to client! |
| **RepNotify** | The variable replicates like the Replicated option, but additionally an `OnRep_<variable name>` function is created in your blueprint. This function is called automatically on the client and server whenever the value changes. |

*[Variable replication dropdown in Blueprint details]*

Many variables in the engine's built-in classes already have replication enabled, so many features work automatically in a multiplayer context.

#### Important Notes on Variable Replication

**Variables that are important to gameplay should only be modified on the server (authority), but both server and clients can read them.** The server modifies the value, and then replication ensures clients receive the updated value.

**Critical:** When you change a value for a replicated variable, it will consider it for replication, but **it won't detect multiple changes within one frame**. If you changed Health from 100 to 80 and then immediately set Health back to 100 again, the client won't be aware that ever happened. At the end of the frame when it's considered for replication, it will see "I started at 100 and my current value is 100. No change occurred; I don't need to tell client machines about that."

---

### 4. RepNotify

**RepNotify** means: do everything that the replicated keyword does, but in addition, when that variable changes (if somebody modifies it), give me a chance to respond to that. Allow me to call a function in response and do something with it.

#### How RepNotify Works

When you set a variable to RepNotify, it automatically calls a function named `OnRep_<variable name>` that you can implement. This function will be called by the engine automatically on the client and the server whenever the value of this variable changes.

*[OnRep function example in Blueprint]*

This is a really handy and powerful way to do things where a gameplay thing changes and it should have associated visual effect changes that clients need to know about. You could make it RepNotify if you want to be notified the second it changes and then react accordingly.

#### Blueprint vs C++ Caveat

**Important:** If you happen to be a programmer or are dealing with programmers doing replication in C++ (not through Blueprints), the behavior of the Notify is slightly different. In Blueprints, when a RepNotify variable is set, the server automatically calls the function. In C++, the RepNotify function is **not** automatically called on the server—if you want it, you have to manually call it. In Blueprints, it's done as a convenience, so you don't have to worry about it.

---

### 5. Function Call Replication

Now we move on to **function call replication**. Before getting into it, you should know the general strategy between when you'd choose Variable Replication or function call replication.

#### General Rule of Thumb

- **Function call replication:** If something should occur once and it's a one-off event that only needs to happen right away and only once (like if something explodes)
- **Variable Replication:** If what you're changing is something that will change and should persist and should be available to clients for a while (like a streetlight switching between states of red, yellow, and green)

### Multicast Functions

A **Multicast** function means when this function is called on the server (you want to make sure you only call it on the server), it will execute that event on the server. Then it's going to tell all client machines that they also need to call this event. Each individual client will get this event as well and run the code.

*[Multicast function example in Blueprint]*

#### Reliable vs Unreliable

Before we get into other options, there's a checkbox that says **Reliable**. With functions, you get a choice on whether replication is reliable.

**Reliable events:**
- Guaranteed to reach their destination
- Use more bandwidth
- Try to avoid sending reliable events too often
- If network bandwidth is full, reliable events will still get through but may be delayed

**Unreliable events:**
- May not reach their destination if network bandwidth is full or if there are more important things to send
- Use less bandwidth
- Most cases where you're only doing something cosmetic, make these unreliable

When you make something Reliable, it will attempt to dispatch immediately. With Multicast, there's an engine feature guarding you from hurting yourself too badly: **If you attempt to call one of these more than two times on the same actor in the same frame, it will start rejecting further calls until the next frame** so you can't completely flood your network.

### Other Replication Options

The other options in the replication dropdown are:

- **Run on Server:** A request from a client to run a function on the server
- **Run on Owning Client:** A request from the server to run a function on a particular client that owns an Actor

These are valid options for Actors that are owned by a Player Controller. For instance, a pawn that you control is owned by a Player Controller. The pawn or the Player Controller are both valid for these options.

---

### 6. Network Relevancy

An important consideration in any network game is making content that handles some of the trickier edge cases in network play. For example: you've created your game, something is occurring, and an important gameplay event has occurred. Let's say a player has gotten a power-up that mutated them into an enemy, like a crazy monster. But then after that happens, a different player joins the game. How do you make sure that player who joins the game in progress knows that the guy is a mutant and can see everything the correct way?

#### Understanding Network Relevancy

At its simplest terms, **network relevancy** determines if an actor is relevant to a particular machine or not at a certain time. If they are, you send the network updates for that machine.

As an optimization, it's important to not send all network data to all machines all the time, or else we wouldn't be able to support all the cool network content that we do. For example, if you're playing on a gigantic map and another player is all the way across the map and you can't even see them, you don't really need to know what they're doing if what they're doing doesn't directly affect you.

#### The Problem with Function-Only Replication

If you try to handle state changes (like opening a chest) with only a Multicast function, there's a problem: if a client isn't receiving network updates at the time (because the actor isn't relevant to them), they will miss the function call entirely. When they later come into range and start receiving updates, they won't know the state has changed.

#### The Problem with Variable-Only Replication

If you try to handle everything with RepNotify variables, clients who join later or come into range will get the correct state, but they'll also execute any associated effects (like particle effects for opening a chest) that should have only happened once when the event originally occurred.

#### The Solution: Combined Approach

The correct approach is to use **a combination of both replication strategies:**

1. Use a **RepNotify variable** to store persistent state (like whether a chest is open)
2. Use a **Multicast function** to handle one-time visual effects (like particle bursts)

**When the event occurs on the server:**
- Set the RepNotify variable (opens chest lid for all current clients)
- Call the Multicast function (plays particle effect for all current clients)

**When a client joins later or comes into range:**
- They receive the replicated variable and see the chest is open (correct state)
- They don't see the particle effect (correct behavior—they missed the moment it opened)

This way, you're using a variable (which saves state) to control the only thing that should persist (whether the lid is open or not), and you're using a Multicast function for things that should only happen once and immediately (the gold particle effect).

---

# Quick Reference Guide

## Replication Decision Tree

```
Need to Sync Data?
├─ One-time Event?
│  ├─ Yes → Use Multicast RPC
│  │       └─ Visual Effects Only? → Make Unreliable
│  │       └─ Critical Event? → Make Reliable
│  └─ No → Persistent State?
│          ├─ Yes → Use RepNotify Variable
│          └─ No → Use Replicated Variable
```

## Common Patterns

### Pattern 1: Health System
```
Server:
  ↓ Authority Check
  ↓ Modify Health (RepNotify)
  ↓ Check Death Condition

Client (via RepNotify):
  ↓ Update UI
  ↓ Play Visual Effects
```

### Pattern 2: Item Pickup
```
Client:
  ↓ Overlap Event
  ↓ Call "RequestPickup" (Run on Server)

Server:
  ↓ Validate Pickup
  ↓ Remove Item from World
  ↓ Add to Inventory (Replicated)
  ↓ Call "PlayPickupEffect" (Multicast)

All Clients:
  ↓ Play Particle/Sound Effects
```

### Pattern 3: Weapon Fire
```
Owning Client:
  ↓ Input Event
  ↓ Play Local Effects (instant feedback)
  ↓ Call "ServerFire" (Run on Server)

Server:
  ↓ Validate Fire (ammo, cooldown)
  ↓ Spawn Projectile (Replicated Actor)
  ↓ Call "MulticastFireEffects"

All Clients:
  ↓ Play Muzzle Flash
  ↓ Play Fire Sound
```

## Replication Checklist

### Actor Setup
- [ ] Enable "Replicates" checkbox
- [ ] Set appropriate Network Priority
- [ ] Configure Net Update Frequency
- [ ] Enable/disable Movement Replication as needed

### Variable Setup
- [ ] Choose appropriate replication type (None/Replicated/RepNotify)
- [ ] Only modify replicated variables on server
- [ ] Use RepNotify for variables that need response
- [ ] Keep replicated variable count minimal

### Function Setup
- [ ] Choose appropriate replication type (Not Replicated/Multicast/Run on Server/Run on Owning Client)
- [ ] Set reliability (Reliable/Unreliable)
- [ ] Ensure proper ownership for RPC targets
- [ ] Add validation in Server RPCs

## Common Issues & Solutions

| Problem | Cause | Solution |
|---------|-------|----------|
| Actor not visible on client | Replicates not enabled | Check "Replicates" in actor defaults |
| Variable not updating | Not set to replicate | Set replication to Replicated/RepNotify |
| RPC not firing | Wrong ownership/authority | Verify target actor ownership chain |
| Visual effects play late | Using RepNotify for effects | Use Multicast RPC for immediate effects |
| Join-in-progress broken | Only using Multicast RPCs | Use RepNotify for persistent state |
| Bandwidth issues | Too many Reliable RPCs | Make cosmetic RPCs Unreliable |
| Client can cheat | Logic on client side | Move important logic to server |

---

# Exercises

Using what you have learned throughout this assignment, complete the following practical exercises to demonstrate your understanding of multiplayer in Blueprints.

## Exercise Requirements

### 1. Project Setup
**Create a new project based on the First-Person template**

**Deliverables:**
- New UE5 project
- Properly configured for multiplayer development

---

### 2. Multiplayer Configuration
**Set the project to run with two players**

**Tasks:**
- Configure Play settings in editor
- Enable proper network modes
- Test with both listen server and client

---

### 3. Character Visualization
**Add the Animation Starter Pack to the project so each character can have a full body skeletal mesh**

*[Animation Starter Pack in Epic Marketplace]*

**Requirements:**
- Download Animation Starter Pack from Epic Marketplace
- Integrate animations with character blueprint
- Ensure animations work for both server and clients
- Verify skeletal mesh visibility across network

---

### 4. Projectile Replication
**Make the projectiles appear on both sides**

**Implementation Checklist:**
- [ ] Enable actor replication on projectile blueprint
- [ ] Test projectile spawning on server
- [ ] Verify projectile visibility on all clients
- [ ] Ensure proper collision detection across network
- [ ] Implement synchronized visual effects

---

### 5. Combat System
**Implement a health system, collision and headshots**

**Components to Implement:**

#### Health System
- Create replicated health variable
- Implement damage application on server
- Use RepNotify for health UI updates
- Handle death/respawn logic

#### Collision Detection
- Configure proper collision channels
- Implement hit detection on server
- Replicate hit events to clients
- Add visual feedback for hits

#### Headshot Mechanics
- Detect headshot collisions
- Apply multiplied damage for headshots
- Create special effects for headshots
- Display headshot indicators

---

## Grading Criteria

| Component | Weight | Criteria |
|-----------|--------|----------|
| Project Setup | 10% | Correct template usage, multiplayer configuration |
| Network Configuration | 15% | Proper server/client setup, testing methodology |
| Character Integration | 20% | Animation pack integration, network visibility |
| Projectile Replication | 25% | Correct replication, synchronized effects |
| Combat System | 30% | Complete health system, proper collision, headshot implementation |

---

## Submission Guidelines

**Include:**
1. Complete project folder (or GitHub repository link)
2. Documentation explaining your implementation
3. Video demonstration of multiplayer functionality
4. Screenshots showing key features working

**Deadline:** As specified by your instructor

**Format:** ZIP file or repository link submitted via course platform

---

## Additional Challenges (Optional)

For students seeking extra credit:

- Implement a respawn system with spawn points
- Add custom visual effects for different weapon types
- Create a scoreboard showing kills/deaths
- Add networked audio feedback
- Implement an armor/shield system

---

## Final Thoughts

Remember the key principles:
- **Server Authority** - Important gameplay decisions happen on the server
- **RepNotify for State** - Use replicated variables for persistent data
- **Multicast for Events** - Use multicast functions for one-time visual effects
- **Test Early and Often** - Test with multiple clients regularly during development

---

## Additional Resources

### Official Documentation
- [Networking Overview](https://dev.epicgames.com/documentation/en-us/unreal-engine/networking-overview-for-unreal-engine)
- [Actor Replication](https://docs.unrealengine.com/en-US/InteractiveExperiences/Networking/Actors)
- [Remote Procedure Calls](https://dev.epicgames.com/documentation/en-us/unreal-engine/remote-procedure-calls-in-unreal-engine)
- [Network Relevancy](https://docs.unrealengine.com/en-US/InteractiveExperiences/Networking/Actors/Relevancy)

### Community Resources
- [Multiplayer Network Compendium](https://cedric-neukirchen.net/docs/category/multiplayer-network-compendium)
- [Unreal Community Wiki - Networking](https://unrealcommunity.wiki/networking-overview-25cjvbe7)
- [Tom Looman's Networking Series](https://www.tomlooman.com/unreal-engine-multiplayer-tips-tricks/)

### Support
- [Unreal Engine Forums](https://forums.unrealengine.com/c/multiplayer-networking/)
- [Unreal Slackers Discord](https://unrealslackers.org/)
- [Reddit r/unrealengine](https://www.reddit.com/r/unrealengine/)

---

**End of Assignment**

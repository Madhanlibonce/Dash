/**
 * Defines the DGame class, the base class for all game logic.
 */
module core.dgame;
import core, components, graphics, utility, utility.awesomium;

import std.string, std.datetime, std.parallelism, std.algorithm, std.traits;
public import core.time;

/**
 * The states the game can be in.
 */
enum EngineState
{
    /// The main game state.
    Run,
    /// Reload all assets at the beginning of the next cycle.
    Reset,
    /// Quit the game and the end of this cycle.
    Quit
}

/**
 * TODO
 */
shared struct UpdateFlags
{
    bool updateScene;
    bool updateUI;
    bool updateTasks;
    //bool updatePhysics;

    /**
     * Set each member to false.
     */
    void pauseAll()
    {
        foreach( member; __traits(allMembers, UpdateFlags) )
            static if( __traits(compiles, __traits(getMember, UpdateFlags, member) = false) )
                __traits(getMember, UpdateFlags, member) = false;
    }

    /**
     * Set each member to true.
     */
    void resumeAll()
    {
        foreach( member; __traits(allMembers, UpdateFlags) )
            static if( __traits(compiles, __traits(getMember, UpdateFlags, member) = true) )
                __traits(getMember, UpdateFlags, member) = true;
    }
}

/**
 * The main game loop manager. Meant to be overridden.
 */
shared class DGame
{
public:
    /// The instance to be running from
    shared static DGame instance;

    /// Current state of the game
    EngineState currentState;

    ///
    UpdateFlags* updateFlags;

    /// The currently active scene
    Scene activeScene;

    /**
     * Overrideable. Returns the name of the window.
     */
    @property string title()
    {
        return "Dash";
    }

    /**
     * Main Game loop.
     */
    final void run()
    {

        // Init tasks
        //TaskManager.initialize();
        start();

        // Loop until there is a quit message from the window or the user.
        while( currentState != EngineState.Quit )
        {
            if( currentState == EngineState.Reset )
                reload();

            //////////////////////////////////////////////////////////////////////////
            // Update
            //////////////////////////////////////////////////////////////////////////

            // Platform specific program stuff
            Graphics.messageLoop();

            // Update time
            Time.update();

            // Update input
            Input.update();

            // Update webcore
            if ( updateFlags.updateUI )
            {
                UserInterface.updateAwesomium();
            }

            // Update physics
            //if( updateFlags.updatePhysics )
            //  PhysicsController.stepPhysics( Time.deltaTime );

            if ( updateFlags.updateTasks )
            {
                uint[] toRemove;    // Indicies of tasks which are done
                foreach( i, task; scheduledTasks )
                {
                    if( task() )
                        toRemove ~= cast(uint)i;
                }
                foreach( i; toRemove )
                {
                    // Get tasks after one being removed
                    auto end = scheduledTasks[ i+1..$ ];
                    // Get tasks before one being removed
                    scheduledTasks = scheduledTasks[ 0..i ];

                    // Allow data stomping
                    (cast(bool function()[])scheduledTasks).assumeSafeAppend();
                    // Add end back
                    scheduledTasks ~= end;
                }
            }

            if ( updateFlags.updateScene )
            {
                activeScene.update();
            }

            // Do the updating of the child class.
            onUpdate();

            //////////////////////////////////////////////////////////////////////////
            // Draw
            //////////////////////////////////////////////////////////////////////////

            // Begin drawing
            Graphics.beginDraw();

            activeScene.draw();

            // Draw in child class
            onDraw();

            // End drawing
            Graphics.endDraw();
        }

        stop();
    }

protected:
    /**
     * To be overridden, logic for when the game is being initalized.
     */
    void onInitialize() { }
    /**
     * To be overridden, called once per frame during the update cycle.
     */
    void onUpdate() { }
    /**
     * To be overridden, called once per frame during the draw cycle.
     */
    void onDraw() { }
    /**
     * To be overridden, called when the came is closing.
     */
    void onShutdown() { }
    /**
     * To be overridden, called when resetting and the state must be saved.
     */
    void onSaveState() { }

private:
    /**
     * Function called to initialize controllers.
     */
    final void start()
    {
        currentState = EngineState.Run;

        updateFlags = new shared UpdateFlags;
        updateFlags.resumeAll();

        logInfo( "Initializing..." );
        auto start = Clock.currTime;
        auto subStart = start;

        Config.initialize();
        Input.initialize();
        Output.initialize();

        logInfo( "Graphics initialization:" );
        subStart = Clock.currTime;
        Graphics.initialize();
        logInfo( "Graphics init time: ", Clock.currTime - subStart );

        logInfo( "Assets initialization:" );
        subStart = Clock.currTime;
        Assets.initialize();
        logInfo( "Assets init time: ", Clock.currTime - subStart );

        Prefabs.initialize();

        UserInterface.initializeAwesomium();

        //Physics.initialize();

        onInitialize();

        logInfo( "Total init time: ", Clock.currTime - start );
    }

    /**
     * Function called to shutdown controllers.
     */
    final void stop()
    {
        onShutdown();
        UserInterface.shutdownAwesomium();
        Assets.shutdown();
        Graphics.shutdown();
    }

    /**
     * Reloads content and yaml.
     */
    final void reload()
    {
        stop();

        start();
    }

    /**
     * Called when engine is resetting.
     */
    final void saveState()
    {
        onSaveState();
    }
}

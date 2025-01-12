// Original grappling hook code by bds#4339 / bds1337 / https://github.com/bds1337/grapplinghook

Hook[] Hookers( maxClients );

Cvar hook_enabled( "hook_enabled", "1", 0 );
Cvar hook_limit( "hook_limit", "1", 0 );

const int HOOK_IDLE     = 0;

const int HOOK_RELEASE  = 2;
const int HOOK_PULLING  = 3;
const int HOOK_LIMIT_MAX_SPEED  = 2200;

bool isHookEnabled;

int sndHook = G_SoundIndex( "sounds/world/player_respawn", false );

class Hook 
{
    Client@ client;
    Entity@ player;

    Entity@ beam;
    Entity@ groundEntity;

    Vec3 fwdTarget;

    bool isActive;
    int hookState;

    // Sky, wall, player
    int hookTarget;

    Vec3 hookEndPos;
    Vec3 hookOrigin;

    Vec3 hookBeamPos;

    float hookLength;

    Hook()
    {
        this.isActive = false;
        this.hookState = HOOK_IDLE;
        this.hookTarget = 0;
    }
    ~Hook(){}
    
    void HookBeamInit()
    {
        @this.beam = @G_SpawnEntity( "hook_beam" );
        this.beam.modelindex = 1;
        this.beam.frame = 8;
        this.beam.type = ET_BEAM;
        this.beam.svflags = SVF_BROADCAST | SVF_TRANSMITORIGIN2;// | SVF_PROJECTILE; // SVF_BROADCAST SVF_NOCLIENT
        this.beam.svflags &= ~SVF_NOCLIENT;
        this.beam.moveType = MOVETYPE_TOSS; //MOVETYPE_LINEARPROJECTILE; 
        this.beam.solid = SOLID_TRIGGER;

        this.beam.linkEntity();
    }

    void PlayerUnstuck( Entity@ hookedPlayer)
    {
        if ( @hookedPlayer.groundEntity != null ) 
        {
            // hax right here 
            Entity @ent = @G_SpawnEntity( ":D" );
            ent.origin = hookedPlayer.origin + Vec3( 0, 0, -20);
            ent.splashDamage( @ent , 25, 0, 35, 0, MOD_EXPLOSIVE );
            // destroy splash entity
            ent.freeEntity();
        }
    }

    void Update() 
    {
        if ( @this.beam == null )
        {
            HookBeamInit();
        }
        
        // +hook
        if ( this.isActive == true ) 
        {
            // spec's cant use hook
            if ( client.getEnt().isGhosting() )
            {
                this.isActive = false;
                return;
            }
            // hook enabled/disabled CVar
            if ( !(hook_enabled.boolean) )
            {
                this.isActive = false;
                G_PrintMsg( client.getEnt(), "Hook disabled via callvote\n" );
                return;
            }
            
            // Calculate first position and draw (beam)hook
            if ( this.hookState == HOOK_IDLE )
            {
                // Disable crounching
                client.pmoveFeatures = client.pmoveFeatures & ~( PMFEAT_CROUCH );
                
                this.hookOrigin = client.getEnt().origin + Vec3( 0, 0, 20 );

                Vec3 player_look;
                player_look = this.hookOrigin + this.fwdTarget * 10000; // hook length limit
                
                Trace tr; // tr.ent: -1 = nothing; 0 = wall; 1 = player
                tr.doTrace( this.hookOrigin, Vec3(), Vec3(), player_look, 0, MASK_SOLID ); //MASK_SHOT MASK_SOLID
                
                this.hookTarget = tr.surfFlags & SURF_SKY; // = 4 if sky
                this.hookEndPos = tr.get_endPos();

                // Make a "sound" effect
                client.getEnt().respawnEffect();
                //G_PositionedSound( this.hookOrigin, CHAN_AUTO, sndHook, ATTN_DISTANT ); // lame
                
                this.hookBeamPos = this.hookOrigin;
                
                this.hookState = HOOK_PULLING;
                this.beam.set_origin2( this.hookEndPos );
                PlayerUnstuck( client.getEnt() );
            }

            Vec3 dir, v0, dv, v;
            // Define hook speed scale
            const float hookScale = 30;
      
            dir = this.hookEndPos - client.getEnt().origin;
            float dist = dir.length();
            dir.normalize();

            if ( this.hookState == HOOK_RELEASE )
            {
                // TODO: pull rope
                // Sets beam entity to end pos

                float newLength = 0;
                if ( newLength < dist )
                {
                    this.hookBeamPos = this.hookBeamPos + this.fwdTarget * 40;
                    newLength = (this.hookBeamPos - client.getEnt().origin).length();
                }
                this.hookLength = newLength;
                this.beam.set_origin2( this.hookBeamPos );

                if ( newLength >= dist )
                {
                    this.hookState = HOOK_PULLING;
                    newLength = 0;

                    if (this.hookTarget == 4)
                    {
                        this.isActive = false;
                        return;
                    }

                    //PlayerUnstuck();
                }
            }
            if ( this.hookState == HOOK_PULLING )
            {
                // cant hook skybox
                if (this.hookTarget == 4)
                {
                    this.isActive = false;
                    return;
                }

                v = client.getEnt().get_velocity();
                
                if ( dist < 300)
                    v = ( v + dir * hookScale ) * 0.98;
                else
                    v = v + dir * hookScale;
                
                if ( hook_limit.boolean )
                {
                    // TODO: allow gain speed while hook_limit (rocketjumping etc)
                    if ( v.length() > HOOK_LIMIT_MAX_SPEED )
                    {
                        v.normalize();
                        v = v * HOOK_LIMIT_MAX_SPEED;
                    }
                }
                client.getEnt().set_velocity( v );
                
            }
            // Draw hook beam
            this.beam.svflags &= ~SVF_NOCLIENT;
            this.beam.set_origin( client.getEnt().origin );
        }
        else
        {
            this.beam.svflags |= SVF_NOCLIENT;
            this.hookState = HOOK_IDLE;
            client.pmoveFeatures = client.pmoveFeatures | ( PMFEAT_CROUCH );
        }
    }
}
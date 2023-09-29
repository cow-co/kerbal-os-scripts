// This script takes us to space in a suborbital parabolic trajectory.
// After this, we will want to run a circularisation procedure

SAS OFF.
CLEARSCREEN.

// Launch logic
SET throt TO 1.0.
LOCK THROTTLE TO throt.

PRINT "Counting down:".
FROM {local countdown is 10.} UNTIL countdown = 0 STEP {SET countdown TO countdown - 1.} DO {
  PRINT "..." + countdown.
  WAIT 1.
}

CLEARSCREEN.

WHEN MAXTHRUST = 0 THEN {
  LIST ENGINES IN elist.

  // If there are any other engines to use, we wanna stage to them
  IF elist:length > 1 {
    PRINT "Staging".
    STAGE.
    PRESERVE.
  }
}.

SET angVelLim TO 2 * CONSTANT:PI.

// This triggers the abort action group, when either of two Bad :tm: conditions are met: 
// - Engine is firing, and nose is pointing > 10 degrees below the horizon
// - Angular rate is > a set value
WHEN (SHIP:FACING:PITCH < -10 AND THROTTLE > 0) OR SHIP:ANGULARVEL:MAG > angVelLim THEN {
  ABORT ON.
  PRINT "DANGER: Automatically Aborting!".
}

// Implementing a simple gravity-turn launch profile: 
// For every 100m/s, pitch down 10 degrees, until 45 degrees
// Once at 45 degrees, we will hold that until apoapsis is 80km
// Speed is limited to 250m/s relative to surface, until 12,000m altitude, at which point the speed restriction is removed

SET desiredApo TO 80000.
SET g TO KERBIN:MU / KERBIN:RADIUS^2. // Using constants to generate the acceleration due to gravity at the surface
SET tgtG TO 1.2.  // The net acceleration (in g) that we are aiming for
SET throtStep TO 0.05.
SET evalInterval TO 0.1.  // How frequently we evaluate the PID loop

SET steer TO HEADING(90,90).
LOCK STEERING TO steer.

WAIT UNTIL SHIP:ALTITUDE > 1000.  // We start our gravity turn at 1km altitude

// We implement a PID Loop (technically just a P-loop for now) to smoothly
// control the throttle
LOCK accel TO SHIP:SENSORS:ACC - SHIP:SENSORS:GRAV.  // The "positive" acceleration of the craft
LOCK gForce TO accel:MAG / g.
LOCK deltaThrot TO throtStep * (tgtG - gForce).

UNTIL APOAPSIS > desiredApo {
  SET block TO SHIP:VELOCITY:SURFACE:MAG / 100.
  SET pitch TO 90 - (block * 10).
  IF pitch > 45 {
    SET steer TO HEADING(90,pitch).
  } ELSE {
    SET steer TO HEADING(90,45).
  }

  // Modulate throttle
  SET throt TO throt + deltaThrot.

  WAIT evalInterval. // We don't want to evaluate this loop too too often

  // TODO Manage throttle and steering on different "threads" (if possible)
}

// Our apoapsis is now where we want it, so let us conserve fuel by switching our engine off
CLEARSCREEN.
PRINT "Cutting throttle now that apo is good".
SET throt TO 0.

WAIT UNTIL SHIP:ALTITUDE > 70000.
// This script takes us to space in a suborbital parabolic trajectory.
// After this, we will want to run a circularisation procedure

DECLARE PARAMETER gain.
SWITCH TO 0.

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
SET limitAlt TO 12000.  // Altitude at which atmospheric drag becomes low enough for us not to worry too much about it any more

SET evalInterval TO 0.1.  // How frequently we evaluate the PID loop

SET spdEps TO 10. // Allowable margin of error for the target speed
SET spdLimit TO 250.
SET lower TO spdLimit - spdEps.
SET upper TO spdLimit + spdEps.
SET minThrot TO 0.35.
LOCK offset TO spdLimit - SHIP:VELOCITY:SURFACE:MAG.

SET steer TO HEADING(90,90).
LOCK STEERING TO steer.

WAIT UNTIL SHIP:ALTITUDE > 1000.  // We start our gravity turn at 1km altitude

UNTIL SHIP:ALTITUDE > limitAlt {
  SET block TO SHIP:VELOCITY:SURFACE:MAG / 10.
  SET pitch TO MAX(45, 90 - block).
  SET steer TO HEADING(90,pitch).
  
  SET curSpd TO SHIP:VELOCITY:SURFACE:MAG.

  IF curSpd < lower {
    SET newThrot TO throt + gain.
    SET throt TO MIN(1.0, newThrot).
  } ELSE IF curSpd > upper {
    SET newThrot TO throt - gain.
    SET throt TO MAX(minThrot, newThrot).
  }

  WAIT evalInterval. // We don't want to evaluate this loop too too often
}

SET orbitEps TO 100.  // Metres
SET steer TO HEADING(90, 45).
SET throt TO 1.

WHEN SHIP:OBT:APOAPSIS > desiredApo THEN {
  // Our apoapsis is now where we want it, so let us conserve fuel by switching our engine off
  CLEARSCREEN.

  PRINT "Cutting throttle now that apo is good".
  SET throt TO 0.
}

// Corrects for deceleration whilst in atmo
UNTIL SHIP:ALTITUDE > 70000 {
  IF SHIP:OBT:APOAPSIS < (desiredApo - orbitEps) {
    SET throt TO 1.
  } ELSE {
    SET throt TO 0.
  }
}

// Circularisation

// Basic implementation for now - just burning prograde at apo until peri ~ apo
SET etaEps TO 10.  // Seconds
LOCK diff TO ABS(SHIP:OBT:APOAPSIS - SHIP:OBT:PERIAPSIS).
UNLOCK STEERING.
LOCK STEERING TO SHIP:PROGRADE.
WAIT UNTIL SHIP:OBT:ETA:APOAPSIS < etaEps.

SET throt TO 1.
UNTIL diff < orbitEps {
  // If our apo starts blowing up, stop thrust
  // TODO The fancier way would be to pitch down to combat the rise in Apo, but that would require tuning of the gain,
  //  so I won't bother with that quite yet
  IF SHIP:OBT:ETA:APOAPSIS > 2 * etaEps AND SHIP:OBT:ETA:APOAPSIS < SHIP:OBT:ETA:PERIAPSIS {
    SET throt TO 0.
  } ELSE {
    SET throt TO 1.
  }
}

SET throt TO 0.
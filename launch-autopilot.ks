// TODO Also implement something to kick off the abort action group if we're rocketing towards the ground, or if angular vel is too high (ie. in a spin)
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

// Implementing a simple gravity-turn launch profile: 
// For every 100m/s, pitch down 10 degrees, until 45 degrees
// Once at 45 degrees, we will hold that until apoapsis is 80km

SET spdEps TO 10. // Allowable margin of error for the target speed
SET throtStep TO 0.001. // How much we increase/decrease throttle by
SET spdLimitAlt TO 12000. // altitude at which we remove our speed restriction
SET spdLimit TO 250.
SET lower TO spdLimit - spdEps.
SET upper TO spdLimit + spdEps.
SET minThrot TO 0.35.

SET desiredApo TO 80000.
SET steer TO HEADING(90,90).
LOCK STEERING TO steer.
UNTIL APOAPSIS > desiredApo {
  SET block TO SHIP:VELOCITY:SURFACE:MAG / 100.
  SET pitch TO 90 - (block * 10).
  IF pitch > 45 {
    SET steer TO HEADING(90,pitch).
  } ELSE {
    SET steer TO HEADING(90,45).
  }

  // Modulate throttle
  // TODO ideally would like to come up with an actual formula for the desired thrust, perhaps based on a desired acceleration
  //  Perhaps make max acceleration modulus = 10m/s/s, scale the accel by distance from desired speed, and go from there
  IF ALTITUDE < spdLimitAlt {
    IF SHIP:VELOCITY:SURFACE:MAG < lower AND throt < 1.0 {
      SET throt TO throt + throtStep.
    } ELSE IF SHIP:VELOCITY:SURFACE:MAG > upper AND throt > minThrot {
      SET throt TO throt - throtStep.
    }
  } ELSE {
    SET throt TO 1.0.
  }

  // FIXME Doesn't set throttle to max (or whatever) after passing spdLimitAlt
  // FIXME Seems to be pitching below 45 degrees again

  // TODO Manage throttle and steering on different "threads" (if possible)
}

CLEARSCREEN.
PRINT "Cutting throttle now that apo is good".

// Our apoapsis is now 100km, so let us conserve fuel by switching our engine off
UNLOCK THROTTLE.
LOCK THROTTLE TO 0.

WAIT UNTIL SHIP:ALTITUDE > 70000.
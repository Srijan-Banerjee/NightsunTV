package com.nightsuntv.app

import cl.puntito.simple_pip_mode.PipCallbackHelperActivityWrapper

/**
 * The wrapper provides the PiP enter/exit callbacks used by the player's
 * PipWidget, so the immersive controls can be restored when the user returns
 * from picture-in-picture.
 */
class MainActivity : PipCallbackHelperActivityWrapper()

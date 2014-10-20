Get the best available polling mechanism.  If we're on a normal webpage, we use requestAnimationFrame.
The benefit is that when the browser loses focus, polling slows down and stops eating cycles.
If we're on the server or in a chrome extension, fall back to setTimeout since that's what's available.

    background = window?.requestAnimationFrame

    if chrome?.extension or not window?.requestAnimationFrame
      background = setTimeout

    module.exports = background
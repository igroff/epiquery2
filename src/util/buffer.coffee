
class RingBuffer
  constructor: (@size=10) ->
    @buffer = []
    @curPos = 0

  insert: () =>

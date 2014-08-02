fs = require 'fs'
Lame = require 'lame'
through = require 'through'
Speaker = require 'speaker'

# start = Date.now()
# splitWriter = (chunkSize, dest) ->
# 	left = null
# 
# 	stream = es.through (chunk) ->
# 		left = chunk
# 
# 		buffer = left
# 		if buffer.length > chunkSize
# 			t = buffer
# 			buffer = t.slice(0, chunkSize)
# 			left = t.slice(chunkSize)
# 		else
# 			left = null
# 
# 		@pause()
# 		dest.write(buffer, null, afterWrite)
# 
# 
# Speaker.prototype._write = (chunk, encoding, done) ->
# 	left = chunk
# 
# 	# chunkSize = this.blockAlign * this.samplesPerFrame
# 
# 	write = ->
# 		b = left
# 		if b.length > chunkSize
# 			t = b
# 			b = t.slice(0, chunkSize)
# 			left = t.slice(chunkSize)
# 		else
# 			left = null
# 		console.log(Date.now() - start)
# 		start = Date.now()
# 		binding.write(handle, b, b.length, afterWrite)
# 
# 	afterWrite = (r) ->
# 		if r isnt b.length
# 			done(new Error('write() failed: ' + r))
# 		else if left
# 			write()
# 		else
# 			done()
# 
# 	write()
# 
timeKeeper = ->
	# Maximum accepted deviation from ideal timing
	EPSILON_MS = 20
	EPSILON_BYTES = EPSILON_MS * 44.1 * 2 * 2

	# State variables
	actualBytes = 0
	start = null
	first = true

	# The actual stream processing function
	return through (chunk) ->
		# Initialise start the at the first chunk of data
		# if start is null then start = Date.now()

		# # Derive the bytes that should have been processed if there was no time skew
		# idealBytes = (Date.now() - start) * 44.1 * 2 * 2

		# diffBytes = actualBytes - idealBytes
		# actualBytes += chunk.length
		# console.log('Time deviation:', (diffBytes / 44.1 / 2 / 2).toFixed(2) + 'ms')

		# # The buffer size should be a multiple of 4
		# diffBytes = diffBytes - (diffBytes % 4)

		# # Only correct the stream if we're out of the EPSILON region
		# if -EPSILON_BYTES < diffBytes < EPSILON_BYTES
		# 	correctedChunk = chunk
		# else
		# 	console.log('Epsilon exceeded! correcting')
		# 	correctedChunk = new Buffer(chunk.length + diffBytes)
		# 	chunk.copy(correctedChunk)

		# chunk = correctedChunk

		# if first
		# 	@queue(chunk)
		# 	first = false
		# 	return

		chunkSize = 4096

		while chunk.length > chunkSize
			@queue(chunk.slice(0, chunkSize))
			chunk = chunk.slice(chunkSize)

		@queue(chunk)


speaker = new Speaker()
timek = timeKeeper()

bufferSize = 0
start = null
first = true
timeout = 0

prevBlock = Date.now()
prevDiff = 0

soundcardOffset = 0

speaker.on('drain', ->
	clearTimeout(timeout)
	# Timeout fires when a write blocks
	timeout = setTimeout(->
		now = Date.now()
		# The first time we fill the soundcard buffer
		# is when we start measuring time
		if first
			console.log('First block')
			start = now
			first = false
			soundcardOffset = bufferSize / 44.1 / 2 / 2
			bufferSize = 0
			return

		# When a write blocks again we can measure how empty
		# it was before blocking. Therefore we learn where the
		# playhead is
		
		idealDuration = now - start + soundcardOffset
		realDuration = bufferSize / 44.1 / 2 / 2 + soundcardOffset
		diff = idealDuration - realDuration
		
		speed = (idealDuration / realDuration).toFixed(2)

		console.log('Real:', realDuration.toFixed(2) + 'ms', 'Ideal:',  idealDuration.toFixed(2) + 'ms', 'Diff:',  diff.toFixed(2) + 'ms', 'Deviation Speed:', speed + 'x')
	, 60)

	if first
		console.log('filling up..')
	bufferSize += 4096
)

# Play a demo song
fs.createReadStream(__dirname + '/utopia.mp3')
	.pipe(new Lame.Decoder())
	.pipe(timek)
	.pipe(speaker)

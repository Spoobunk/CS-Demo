local newdecoder = require 'libs.lunajson.src.lunajson.decoder'
local newencoder = require 'libs.lunajson.src.lunajson.encoder'
local sax = require 'libs.lunajson.src.lunajson.sax'
-- If you need multiple contexts of decoder and/or encoder,
-- you can require lunajson.decoder and/or lunajson.encoder directly.
return {
	decode = newdecoder(),
	encode = newencoder(),
	newparser = sax.newparser,
	newfileparser = sax.newfileparser,
}

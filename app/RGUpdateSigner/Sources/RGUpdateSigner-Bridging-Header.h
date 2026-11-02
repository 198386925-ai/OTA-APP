// Bridging header for the RGUpdateSigner target: exposes the
// bundled zsign C bridge (../CBridge/zsign/luiyo_zsign.h) to the
// Swift sources. In an SPM layout, instead make the Swift target
// depend on the CBridge C target and import it.
#include "luiyo_zsign.h"

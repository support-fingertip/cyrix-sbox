({
    doInit: function (component, event, helper) {
        // 1. Check recordId from force:hasRecordId
        var recordId = component.get("v.recordId");
        if (recordId) {
            component.set("v.opportunityId", recordId);
            return;
        }

        // 2. Check pageReference state for custom params
        var pageRef = component.get("v.pageReference");
        if (pageRef && pageRef.state) {
            var oppId =
                pageRef.state.c__opportunityId ||
                pageRef.state.c__recordId ||
                pageRef.state.recordId;
            if (oppId) {
                component.set("v.opportunityId", oppId);
                return;
            }

            // 3. Parse inContextOfRef (related list "New" button context)
            if (pageRef.state.inContextOfRef) {
                var oppFromCtx = this.parseInContextOfRef(
                    pageRef.state.inContextOfRef
                );
                if (oppFromCtx) {
                    component.set("v.opportunityId", oppFromCtx);
                    return;
                }
            }
        }

        // 4. Fallback: extract Opportunity Id from URL
        var oppFromUrl = this.extractOppIdFromUrl();
        if (oppFromUrl) {
            component.set("v.opportunityId", oppFromUrl);
            return;
        }

        // 5. No context found — show error
        var toastEvent = $A.get("e.force:showToast");
        if (toastEvent) {
            toastEvent.setParams({
                title: "Error",
                message:
                    "Please create a new Quote from the Opportunity record page using the 'Create Quote' button.",
                type: "error",
            });
            toastEvent.fire();
        }

        var navEvent = $A.get("e.force:navigateToObjectHome");
        if (navEvent) {
            navEvent.setParams({ scope: "Quote" });
            navEvent.fire();
        }
    },

    /**
     * Parses the inContextOfRef parameter to extract parent record Id.
     * Handles URL-safe base64 and version prefixes (e.g. "1.eyJ0eXBl...").
     */
    parseInContextOfRef: function (encoded) {
        if (!encoded) return null;

        try {
            // Remove version prefix if present (e.g. "1." or "2.")
            var b64 = encoded;
            if (/^\d+\./.test(b64)) {
                b64 = b64.substring(b64.indexOf(".") + 1);
            }

            // Convert URL-safe base64 to standard base64
            b64 = b64.replace(/-/g, "+").replace(/_/g, "/");

            // Add padding if needed
            while (b64.length % 4 !== 0) {
                b64 += "=";
            }

            var decoded = window.atob(b64);
            var context = JSON.parse(decoded);

            // Extract recordId from context
            if (context && context.attributes && context.attributes.recordId) {
                return context.attributes.recordId;
            }

            // Alternative structure: context.recordId
            if (context && context.recordId) {
                return context.recordId;
            }
        } catch (e) {
            console.warn(
                "Could not parse inContextOfRef:",
                e,
                "raw:",
                encoded
            );
        }

        return null;
    },

    /**
     * Extracts an Opportunity Id (prefix 006) from the current page URL.
     * Works with both classic URL params and Lightning hash-based routes.
     */
    extractOppIdFromUrl: function () {
        try {
            var fullUrl = window.location.href;

            // Check query params
            var urlParams = new URLSearchParams(window.location.search);
            var oppParam =
                urlParams.get("oppId") ||
                urlParams.get("opportunityId") ||
                urlParams.get("retURL");
            if (oppParam) {
                // retURL might be like /006xxxx, extract the Id
                var idMatch = oppParam.match(/006[a-zA-Z0-9]{12,15}/);
                if (idMatch) return idMatch[0];
                if (oppParam.startsWith("006")) return oppParam;
            }

            // Search the full URL (hash + path) for an Opportunity Id pattern
            var matches = fullUrl.match(/006[a-zA-Z0-9]{12,15}/g);
            if (matches && matches.length > 0) {
                return matches[0];
            }
        } catch (e) {
            console.warn("Could not extract Opportunity Id from URL:", e);
        }

        return null;
    },
})

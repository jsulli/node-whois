import { lookupAddress, processData } from "../app"


describe('get address results ', () => {

    it('finds good data on valid URL', () => {
        lookupAddress('google.com', (response) => {
            expect(response).toContain("Google LLC")
        })
    })

    it('finds good data on valid IP address', () => {
        lookupAddress('8.8.8.8', (response) => {
            expect(response).toContain("American Registry for Internet Numbers")
        })
    })
})

describe('Process address result', () => {

    it('Removes entries with Registrar', () => {
        expect(processData("Registrar")).not.toContain("Registrar")
    })

    it('removes entries with Domain Status', () => {
        expect(processData("Domain Status")).not.toContain("Domain Status")
    })

    it('removes entries with Domain Status', () => {
        expect(processData("Domain Status")).not.toContain("Domain Status")
    })

    it('removes entries with DNSSEC', () => {
        expect(processData("DNSSEC")).not.toContain("DNSSEC")
    })

    it('returns error code with an invalid address', () => {
        expect(processData("% This is the RIPE Database query service.")).toBe("ERROR_BAD_ADDRESS")
    })
})

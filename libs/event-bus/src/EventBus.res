// Main EventBus module - exports all components

// Enable Sury JSON support (required for Envelope serialization)
S.enableJson()

// Envelope for message wrapping
module Envelope = EventBus__Envelope

// Transport interface
module Transport = EventBus__Transport

// Bus implementations
module LocalBus = EventBus__LocalBus
module RemoteBus = EventBus__RemoteBus

// Transport implementations
module StdioTransport = EventBus__Transport__Stdio
module SubprocessTransport = EventBus__Transport__Subprocess

// Subprocess helpers
module Subprocess = EventBus__Helpers__Subprocess

// Schema-driven event helpers
module Event = EventBus__Event

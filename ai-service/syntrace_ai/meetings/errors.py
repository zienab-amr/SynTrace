"""
meetings/errors.py
The errors the meeting services raise. `status` is the HTTP status the API returns for each.
"""


class MeetingError(Exception):
    """A request the service must refuse. `status` is the HTTP status to return."""
    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


class ExtractionUnavailable(MeetingError):
    def __init__(self, message="meeting extraction is unavailable"):
        super().__init__(message, 503)


class BadReply(ExtractionUnavailable):
    """The model answered, but not with the JSON asked for."""

local TS = Talksmith

function TS.Editor.NewHistory(limit)
    local history = {
        undo = {},
        redo = {},
        limit = limit or 50,
    }

    function history:Push(document)
        self.undo[#self.undo + 1] = TS.Utils.Copy(document)

        if #self.undo > self.limit then
            table.remove(self.undo, 1)
        end

        self.redo = {}
    end

    function history:Undo(current)
        if #self.undo == 0 then
            return
        end

        self.redo[#self.redo + 1] = TS.Utils.Copy(current)

        return table.remove(self.undo)
    end

    function history:Redo(current)
        if #self.redo == 0 then
            return
        end

        self.undo[#self.undo + 1] = TS.Utils.Copy(current)

        return table.remove(self.redo)
    end

    return history
end
